import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant_record.dart';

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
  Future<List<RestaurantRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    try {
      return RestaurantRecord.decodeList(jsonStr);
    } catch (_) {
      return [];
    }
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
        lastVisitedAt: DateTime.now(),
      );

      records[existingIndex] = targetRecord;
    } else {
      // 初訪問の店 → 新規ピン（chargeCount = 1: 銅ピン）として作成
      targetRecord = RestaurantRecord(
        id: id.isNotEmpty ? id : 'shop_${DateTime.now().millisecondsSinceEpoch}',
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

  /// 指定店舗のチャージを1件削除または全件クリア（デバッグ・管理用）
  Future<List<RestaurantRecord>> deleteRecord(String id) async {
    final records = await loadRecords();
    records.removeWhere((r) => r.id == id);
    await _saveAll(records);
    return records;
  }

  Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _saveAll(List<RestaurantRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, RestaurantRecord.encodeList(records));
  }
}

