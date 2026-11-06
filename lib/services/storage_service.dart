import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant_record.dart';
import '../models/want_to_visit.dart';
import '../utils/place_match.dart';

/// N1：行きたいリストへの追加結果。
enum AddWantResult {
  added,
  alreadyInWantList,
  alreadyRegistered,
}

/// 登録結果レスポンス
class SaveChargeResult {
  final RestaurantRecord record;
  final List<RestaurantRecord> allRecords;
  final bool isRepeat;

  const SaveChargeResult({
    required this.record,
    required this.allRecords,
    required this.isRepeat,
  });
}

/// ステップ⑤〜⑨：店舗データ・ユーザー設定・称号・PRO状態のローカル保存（SharedPreferences）サービス
class StorageService {
  static const String _storageKey = 'gourmet_map_restaurant_records_v1';
  static const String _userNameKey = 'gourmet_map_user_name_v1';
  static const String _customTitleKey = 'gourmet_map_custom_title_v1';
  static const String _cardThemeIndexKey = 'gourmet_map_card_theme_idx_v1';
  static const String _isProMemberKey = 'gourmet_map_is_pro_member_v1';
  static const String _wantListKey = 'gourmet_map_want_list_v1';

  /// ユーザー名（グルメ名刺用）を読み込む
  Future<String> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey) ?? 'グルメ開拓者';
  }

  /// ユーザー名（グルメ名刺用）を保存する
  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userNameKey,
      name.trim().isEmpty ? 'グルメ開拓者' : name.trim(),
    );
  }

  /// 装備中のカスタム称号を読み込む（空の場合は自動判定称号を使用）
  Future<String?> loadCustomTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customTitleKey);
  }

  Future<void> saveCustomTitle(String? title) async {
    final prefs = await SharedPreferences.getInstance();
    if (title == null || title.isEmpty) {
      await prefs.remove(_customTitleKey);
    } else {
      await prefs.setString(_customTitleKey, title);
    }
  }

  /// 名刺デザインテーマ番号を読み込む（0: ロイヤル黒金, 1: サイバーネオン, 2: 和風雅）
  Future<int> loadCardThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cardThemeIndexKey) ?? 0;
  }

  Future<void> saveCardThemeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cardThemeIndexKey, index);
  }

  /// PROプラン（広告非表示・全テーマ解放）状態を読み込む
  Future<bool> loadIsProMember() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isProMemberKey) ?? false;
  }

  Future<void> saveIsProMember(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isProMemberKey, isPro);
  }

  /// 保存済みの全店舗データを読み込む
  /// F4：写真はファイルに分離して保存されているため、読み込み時に
  /// Base64へ戻してから返す（呼び出し側の扱いは従来どおり）。
  Future<List<RestaurantRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    try {
      final decoded = RestaurantRecord.decodeList(jsonStr);
      final dir = await _imageDir();
      if (dir == null) return decoded;
      final result = <RestaurantRecord>[];
      for (final record in decoded) {
        result.add(await _rehydrateImage(record));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // F4：写真のファイル分離（SharedPreferences の肥大化防止）
  // 保存時：Base64 → ファイルへ書き出し、本体JSONにはパスだけを残す。
  // 読込時：ファイル → Base64へ戻す。ファイルが使えない環境では従来どおり
  // Base64のまま保存する（フォールバック）。
  // ---------------------------------------------------------------------------

  Future<Directory?> _imageDir() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/record_images');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      return null;
    }
  }

  File _imageFile(Directory dir, String recordId) {
    final safeId = recordId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${dir.path}/$safeId.jpg');
  }

  RestaurantRecord _rebuild(
    RestaurantRecord r, {
    required String? imagePath,
    required String? imageBase64,
  }) {
    return RestaurantRecord(
      id: r.id,
      name: r.name,
      category: r.category,
      latitude: r.latitude,
      longitude: r.longitude,
      chargeCount: r.chargeCount,
      priceRange: r.priceRange,
      goodPoints: r.goodPoints,
      imagePath: imagePath,
      imageBase64: imageBase64,
      lastVisitedAt: r.lastVisitedAt,
      comment: r.comment,
      isShared: r.isShared,
    );
  }

  Future<RestaurantRecord> _externalizeImage(
    RestaurantRecord record,
    Directory dir,
  ) async {
    final base64 = record.imageBase64;
    if (base64 == null || base64.isEmpty) return record;
    try {
      final file = _imageFile(dir, record.id);
      await file.writeAsBytes(base64Decode(base64), flush: true);
      return _rebuild(record, imagePath: file.path, imageBase64: null);
    } catch (_) {
      return record; // 失敗したら Base64 のまま保存する
    }
  }

  Future<RestaurantRecord> _rehydrateImage(RestaurantRecord record) async {
    if (record.imageBase64 != null && record.imageBase64!.isNotEmpty) {
      return record;
    }
    final path = record.imagePath;
    if (path == null || path.isEmpty) return record;
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return _rebuild(
          record,
          imagePath: path,
          imageBase64: base64Encode(bytes),
        );
      }
    } catch (_) {
      // ファイルが読めない場合は写真なしとして扱う
    }
    return record;
  }

  /// 店舗を登録またはリピートチャージ（count + 1）する
  /// すでに同じ店名（または同じID）の店舗が登録されている場合、新規ピンを増やさず chargeCount を +1 します。
  Future<SaveChargeResult> saveOrChargeRestaurant({
    required String id,
    required String name,
    required String category,
    required double latitude,
    required double longitude,
    required String priceRange,
    required List<String> goodPoints,
    String? imagePath,
    String? imageBase64,
    String? comment,
  }) async {
    final records = await loadRecords();
    final normalizedName = name.trim();

    // 既存店舗を検索（店名一致 または ID一致）
    final existingIndex = records.indexWhere(
      (r) => r.name.trim() == normalizedName || r.id == id,
    );

    late final RestaurantRecord targetRecord;
    final bool isRepeat = existingIndex != -1;

    if (isRepeat) {
      // 【重要】すでに登録済みの店 → 新規ピンを増やさず「来店チャージ数（chargeCount）」を +1！
      final existing = records[existingIndex];

      // 良かった点タグは既存のタグと今回の選択タグを重複なしで統合（または最新選択を反映）
      final mergedTags = <String>{
        ...existing.goodPoints,
        ...goodPoints,
      }.toList();

      targetRecord = existing.copyWith(
        chargeCount: existing.chargeCount + 1,
        priceRange: priceRange,
        goodPoints: mergedTags.isEmpty ? existing.goodPoints : mergedTags,
        imagePath: (imagePath != null && imagePath.isNotEmpty)
            ? imagePath
            : existing.imagePath,
        imageBase64: (imageBase64 != null && imageBase64.isNotEmpty)
            ? imageBase64
            : existing.imageBase64,
        comment: comment ?? existing.comment,
        lastVisitedAt: DateTime.now(),
      );

      records[existingIndex] = targetRecord;
    } else {
      // 初訪問の店 → 新規ピン（chargeCount = 1: 銅ピン）として作成
      targetRecord = RestaurantRecord(
        id: id.isNotEmpty
            ? id
            : 'shop_${DateTime.now().millisecondsSinceEpoch}',
        name: normalizedName,
        category: category,
        latitude: latitude,
        longitude: longitude,
        chargeCount: 1,
        priceRange: priceRange,
        goodPoints: goodPoints,
        imagePath: imagePath,
        imageBase64: imageBase64,
        lastVisitedAt: DateTime.now(),
        comment: comment ?? '',
      );

      records.add(targetRecord);
    }

    await _saveAll(records);

    return SaveChargeResult(
      record: targetRecord,
      allRecords: records,
      isRepeat: isRepeat,
    );
  }

  /// 既存の記録をそのまま更新する（コメント・共有ON/OFFの変更用）。
  Future<List<RestaurantRecord>> updateRecord(
    RestaurantRecord updated,
  ) async {
    final records = await loadRecords();
    final index = records.indexWhere((r) => r.id == updated.id);
    if (index == -1) return records;
    records[index] = updated;
    await _saveAll(records);
    return records;
  }

  /// 指定店舗のチャージを1件削除または全件クリア（デバッグ・管理用）
  Future<List<RestaurantRecord>> deleteRecord(String id) async {
    final records = await loadRecords();
    records.removeWhere((r) => r.id == id);
    await _saveAll(records);
    // F4：分離した写真ファイルも一緒に消す（失敗しても無視）
    final dir = await _imageDir();
    if (dir != null) {
      try {
        final file = _imageFile(dir, id);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    return records;
  }

  Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // ---------------------------------------------------------------------------
  // N1：行きたいリスト
  // ---------------------------------------------------------------------------

  Future<List<WantToVisit>> loadWantList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_wantListKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      return WantToVisit.decodeList(jsonStr);
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveWantList(List<WantToVisit> wants) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wantListKey, WantToVisit.encodeList(wants));
  }

  /// 行きたい店を追加する。すでに登録済みの店／すでに追加済みの店は弾く。
  Future<({AddWantResult result, List<WantToVisit> wants})> addWant(
    WantToVisit want,
  ) async {
    final records = await loadRecords();
    final isRegistered = records.any(
      (r) => PlaceMatch.matches(
        lat: want.latitude,
        lng: want.longitude,
        name: want.name,
        otherLat: r.latitude,
        otherLng: r.longitude,
        otherName: r.name,
      ),
    );
    if (isRegistered) {
      return (
        result: AddWantResult.alreadyRegistered,
        wants: await loadWantList(),
      );
    }

    final wants = await loadWantList();
    final isDuplicate = wants.any(
      (w) => PlaceMatch.matches(
        lat: want.latitude,
        lng: want.longitude,
        name: want.name,
        otherLat: w.latitude,
        otherLng: w.longitude,
        otherName: w.name,
      ),
    );
    if (isDuplicate) {
      return (result: AddWantResult.alreadyInWantList, wants: wants);
    }

    wants.add(want);
    await _saveWantList(wants);
    return (result: AddWantResult.added, wants: wants);
  }

  Future<List<WantToVisit>> removeWant(String id) async {
    final wants = await loadWantList();
    wants.removeWhere((w) => w.id == id);
    await _saveWantList(wants);
    return wants;
  }

  /// 訪問して通常登録した店と一致する「行きたい」を卒業させる。
  /// 卒業した件数を返す。
  Future<({int graduatedCount, List<WantToVisit> wants})> graduateWantsFor(
    RestaurantRecord record,
  ) async {
    final wants = await loadWantList();
    final before = wants.length;
    wants.removeWhere(
      (w) => PlaceMatch.matches(
        lat: w.latitude,
        lng: w.longitude,
        name: w.name,
        otherLat: record.latitude,
        otherLng: record.longitude,
        otherName: record.name,
      ),
    );
    if (wants.length != before) {
      await _saveWantList(wants);
    }
    return (graduatedCount: before - wants.length, wants: wants);
  }

  /// F4：保存前に写真をファイルへ分離し、本体JSONを軽くする。
  Future<void> _saveAll(List<RestaurantRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final dir = await _imageDir();
    var toStore = records;
    if (dir != null) {
      toStore = [];
      for (final record in records) {
        toStore.add(await _externalizeImage(record, dir));
      }
    }
    await prefs.setString(_storageKey, RestaurantRecord.encodeList(toStore));
  }
}
