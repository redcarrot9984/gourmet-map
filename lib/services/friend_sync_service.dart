import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/friend_code.dart';
import '../models/friend_profile.dart';
import '../models/restaurant_record.dart';
import '../models/shared_record.dart';
import 'share_service.dart';

/// フレンドコードでの取得結果。
enum FriendFetchStatus {
  found, // 実在するフレンドを取得できた
  notFound, // コードは正しい形式だが、該当するフレンドがいない
  invalidFormat, // コードの形式が違う
  offline, // 通信できず確認できなかった
}

/// フレンド機能 v2：Supabase 匿名認証＋自動同期サービス。
///
/// 設計（gourmet-map-friend-redesign.md）：
/// - 接続先は開発者の Supabase プロジェクト1つに固定し、利用者の設定は不要
/// - 起動時に匿名アカウントを自動発行し、書き込みは RLS で自分の行だけに制限
/// - フレンド取得は RPC `get_map_by_code`（コード完全一致時のみ1件返す）経由
/// - 共有データは写真・訪問日時を含まない [SharedRecord] 形式のみ
/// - 同期失敗時は「未送信フラグ」を端末に残し、次回トリガーで自動再送する
class FriendSyncService {
  static const String _myCodeKey = 'gourmet_map_my_friend_code_v2';
  static const String _friendsListKey = 'gourmet_map_friends_list_v1';
  static const String _pendingKey = 'gourmet_map_sync_pending_v2';
  static const String _lastSyncKey = 'gourmet_map_last_sync_at_v2';

  static const String tableName = 'shared_maps';

  bool _supabaseReady = false;
  bool _authReady = false;
  String? _myCode;

  /// 未送信の変更があるかどうか（同期失敗時に true が端末へ残る）。
  bool hasPendingSync = false;

  /// 最後にクラウド同期できた時刻。
  DateTime? lastSyncAt;

  Timer? _debounceTimer;
  ({String userName, List<RestaurantRecord> records})? _queuedPayload;

  bool get isAuthReady => _authReady;
  String? get myCode => _myCode;

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  void dispose() {
    _debounceTimer?.cancel();
  }

  // ---------------------------------------------------------------------------
  // 初期化・認証
  // ---------------------------------------------------------------------------

  /// 保存済みの自分のコード／フレンド一覧を読み込み、匿名認証と
  /// 自分の行の用意（なければ作成）まで行う。オフラインでも例外は投げず、
  /// ローカルデータだけで利用を開始できる。
  Future<({String myCode, List<FriendProfile> friends})> initialize({
    required String userName,
    required List<RestaurantRecord> records,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    hasPendingSync = prefs.getBool(_pendingKey) ?? false;
    final lastMs = prefs.getInt(_lastSyncKey);
    if (lastMs != null) {
      lastSyncAt = DateTime.fromMillisecondsSinceEpoch(lastMs);
    }
    _myCode = prefs.getString(_myCodeKey);
    final friends = await loadFriends();

    await _ensureSupabaseAndAuth();
    if (_authReady) {
      await _ensureMyRow(userName: userName, records: records);
      if (hasPendingSync) {
        await syncMyMap(userName: userName, records: records);
      }
    }

    return (myCode: _myCode ?? 'GM-?????-?????', friends: friends);
  }

  Future<void> _ensureSupabaseAndAuth() async {
    try {
      if (!_supabaseReady) {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.publishableKey,
        );
        _supabaseReady = true;
      }
      if (_client.auth.currentSession == null) {
        await _client.auth.signInAnonymously();
      }
      _authReady = _client.auth.currentUser != null;
    } catch (_) {
      // オフライン等：ローカル動作を継続し、次回トリガーで再試行する。
      _authReady = false;
    }
  }

  // ---------------------------------------------------------------------------
  // 自分のマップの同期
  // ---------------------------------------------------------------------------

  /// 名刺テーマのインデックス（main から設定される）。
  /// サーバー側に card_theme 列がある場合だけ別途送る（無い環境では無視）。
  int cardThemeIndex = 0;

  /// 自分のアバター絵文字（main から設定される）。
  String avatarEmoji = '🔥';

  Future<void> _pushCardTheme() async {
    if (!_authReady || _uid == null) return;
    try {
      await _client
          .from(tableName)
          .update({'card_theme': cardThemeIndex}).eq('owner_id', _uid!);
    } catch (_) {
      // 列が無い環境ではテーマ共有だけ諦める（同期本体は成功扱い）
    }
  }

  Map<String, dynamic> _buildPayload({
    required String code,
    required String userName,
    required List<RestaurantRecord> records,
  }) {
    return {
      'owner_id': _uid,
      'friend_code': code,
      'display_name': userName,
      'avatar_emoji': avatarEmoji,
      'title': ShareService.calculateGourmetTitle(records),
      // 店ごとの共有OFF（isShared=false）の店は相手に送らない
      'records_json': records
          .where((r) => r.isShared)
          .map((r) => SharedRecord.fromRecord(r).toJson())
          .toList(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// サーバー上に自分の行が無ければ作成し、自分のコードを確定させる。
  /// 既に行がある場合はサーバー側のコードを正として端末へ反映する。
  Future<void> _ensureMyRow({
    required String userName,
    required List<RestaurantRecord> records,
  }) async {
    if (!_authReady || _uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final existing = await _client
          .from(tableName)
          .select('friend_code')
          .eq('owner_id', _uid!)
          .maybeSingle();
      final serverCode = existing?['friend_code'] as String?;
      if (serverCode != null && serverCode.isNotEmpty) {
        if (_myCode != serverCode) {
          _myCode = serverCode;
          await prefs.setString(_myCodeKey, serverCode);
        }
        return;
      }

      // 行が無い：保存済みコード（あれば）か新規コードで作成する。
      for (var attempt = 0; attempt < 5; attempt++) {
        final code = _myCode ?? FriendCode.generate();
        try {
          await _client.from(tableName).upsert(
                _buildPayload(code: code, userName: userName, records: records),
              );
          _myCode = code;
          await prefs.setString(_myCodeKey, code);
          await _markSynced();
          return;
        } on PostgrestException catch (e) {
          // 23505 = unique 違反（コードが他者と衝突）→ 新しいコードで再試行。
          if (e.code == '23505') {
            _myCode = null;
            continue;
          }
          rethrow;
        }
      }
    } catch (_) {
      await _setPending(true);
    }
  }

  /// 自分のマップを今すぐクラウドへ同期する。
  Future<({bool synced, String message})> syncMyMap({
    required String userName,
    required List<RestaurantRecord> records,
  }) async {
    if (!_authReady) {
      await _ensureSupabaseAndAuth();
    }
    if (_authReady && _myCode == null) {
      await _ensureMyRow(userName: userName, records: records);
    }
    if (!_authReady || _uid == null || _myCode == null) {
      await _setPending(true);
      return (
        synced: false,
        message: 'ローカルに保存しました（回線が戻り次第、自動で同期します）',
      );
    }
    try {
      await _client.from(tableName).upsert(
            _buildPayload(code: _myCode!, userName: userName, records: records),
          );
      await _pushCardTheme();
      await _markSynced();
      return (
        synced: true,
        message: '☁️ クラウドに同期しました（${records.length}店舗）',
      );
    } catch (_) {
      await _setPending(true);
      return (
        synced: false,
        message: 'ローカルに保存しました（回線が戻り次第、自動で同期します）',
      );
    }
  }

  /// 変更時の自動同期：連続操作を約2秒のデバウンスでまとめて送信する。
  void scheduleSync({
    required String userName,
    required List<RestaurantRecord> records,
  }) {
    _queuedPayload = (userName: userName, records: records);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      final payload = _queuedPayload;
      if (payload != null) {
        unawaited(
          syncMyMap(userName: payload.userName, records: payload.records),
        );
      }
    });
  }

  /// フレンドコードを再発行する（旧コードは即座に無効になる）。
  Future<({String? newCode, String message})> reissueMyCode({
    required String userName,
    required List<RestaurantRecord> records,
  }) async {
    if (!_authReady) {
      await _ensureSupabaseAndAuth();
    }
    if (!_authReady || _uid == null) {
      return (newCode: null, message: '通信できないため、コードを再発行できませんでした');
    }
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = FriendCode.generate();
      try {
        await _client.from(tableName).upsert(
              _buildPayload(code: code, userName: userName, records: records),
            );
        _myCode = code;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_myCodeKey, code);
        await _markSynced();
        return (newCode: code, message: '新しいフレンドコードを発行しました');
      } on PostgrestException catch (e) {
        if (e.code == '23505') continue; // 衝突 → 別コードで再試行
        return (newCode: null, message: 'コードの再発行に失敗しました');
      } catch (_) {
        return (newCode: null, message: 'コードの再発行に失敗しました');
      }
    }
    return (newCode: null, message: 'コードの再発行に失敗しました（再試行してください）');
  }

  Future<void> _markSynced() async {
    final prefs = await SharedPreferences.getInstance();
    lastSyncAt = DateTime.now();
    await prefs.setInt(_lastSyncKey, lastSyncAt!.millisecondsSinceEpoch);
    await _setPending(false);
  }

  Future<void> _setPending(bool value) async {
    hasPendingSync = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, value);
  }

  // ---------------------------------------------------------------------------
  // フレンドの取得・管理
  // ---------------------------------------------------------------------------

  /// 保存済みのフレンドリストを読み込む。
  Future<List<FriendProfile>> loadFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_friendsListKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      return FriendProfile.decodeList(jsonStr);
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveFriends(List<FriendProfile> friends) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_friendsListKey, FriendProfile.encodeList(friends));
  }

  /// RPC で1件だけ取得する共通処理。通信不可・未検出は null を返す。
  Future<Map<String, dynamic>?> _fetchRowByCode(String code) async {
    final res = await _client.rpc('get_map_by_code', params: {'p_code': code});
    if (res is List && res.isNotEmpty) {
      return res.first as Map<String, dynamic>;
    }
    return null;
  }

  FriendProfile _rowToFriend(String code, Map<String, dynamic> row) {
    final rawList = row['records_json'] as List<dynamic>? ?? [];
    final now = DateTime.now();
    final records = rawList
        .map((e) => SharedRecord.fromJson(e as Map<String, dynamic>)
            .toRestaurantRecord(receivedAt: now))
        .toList();
    return FriendProfile(
      friendCode: code,
      displayName: (row['display_name'] ?? 'グルメ友達').toString(),
      avatarEmoji: (row['avatar_emoji'] ?? '🍴').toString(),
      title: (row['title'] ?? '⚡ 爆速グルメハンター').toString(),
      colorValue: _pickColorForCode(code),
      records: records,
      syncedAt: now,
      cardThemeIndex: (row['card_theme'] as num?)?.toInt() ?? 0,
    );
  }

  /// フレンドコードでフレンドを追加（既存なら最新に更新）する。
  /// 存在しないコードでは何も作らない（デモ生成はしない）。
  Future<
      ({
        FriendProfile? friend,
        List<FriendProfile> allFriends,
        FriendFetchStatus status,
      })> addFriendByCode(String friendCodeInput) async {
    final code = FriendCode.normalize(friendCodeInput);
    final currentFriends = await loadFriends();

    if (!FriendCode.isValidFormat(code)) {
      return (
        friend: null,
        allFriends: currentFriends,
        status: FriendFetchStatus.invalidFormat,
      );
    }
    if (code == _myCode) {
      return (
        friend: null,
        allFriends: currentFriends,
        status: FriendFetchStatus.invalidFormat,
      );
    }
    if (!_authReady) {
      await _ensureSupabaseAndAuth();
    }
    if (!_authReady) {
      return (
        friend: null,
        allFriends: currentFriends,
        status: FriendFetchStatus.offline,
      );
    }

    try {
      final row = await _fetchRowByCode(code);
      if (row == null) {
        return (
          friend: null,
          allFriends: currentFriends,
          status: FriendFetchStatus.notFound,
        );
      }
      final friend = _rowToFriend(code, row);
      final existingIndex =
          currentFriends.indexWhere((f) => f.friendCode == code);
      if (existingIndex != -1) {
        currentFriends[existingIndex] = friend;
      } else {
        currentFriends.add(friend);
      }
      await _saveFriends(currentFriends);
      return (
        friend: friend,
        allFriends: currentFriends,
        status: FriendFetchStatus.found,
      );
    } catch (_) {
      return (
        friend: null,
        allFriends: currentFriends,
        status: FriendFetchStatus.offline,
      );
    }
  }

  /// 追加済みフレンド（サンプル除く）のマップを最新に更新する。
  /// 相手がコード再発行などで見つからなくなった場合は、勝手に消さず
  /// 端末内のキャッシュをそのまま残す。
  Future<List<FriendProfile>> refreshFriends() async {
    final friends = await loadFriends();
    if (!_authReady) {
      await _ensureSupabaseAndAuth();
    }
    if (!_authReady) return friends;

    var changed = false;
    for (var i = 0; i < friends.length; i++) {
      final friend = friends[i];
      if (friend.isSample) continue;
      try {
        final row = await _fetchRowByCode(friend.friendCode);
        if (row != null) {
          friends[i] = _rowToFriend(friend.friendCode, row);
          changed = true;
        }
      } catch (_) {
        // 個別の失敗は無視してキャッシュ表示を継続する。
      }
    }
    if (changed) {
      await _saveFriends(friends);
    }
    return friends;
  }

  /// サンプルフレンド（体験用・端末内のみ）を追加する。
  Future<({FriendProfile friend, List<FriendProfile> allFriends})>
      addSampleFriend({
    required String sampleCode,
    required LatLng baseLatLng,
  }) async {
    final currentFriends = await loadFriends();
    final friend = SampleFriends.build(sampleCode, baseLatLng);
    final existingIndex =
        currentFriends.indexWhere((f) => f.friendCode == sampleCode);
    if (existingIndex != -1) {
      currentFriends[existingIndex] = friend;
    } else {
      currentFriends.add(friend);
    }
    await _saveFriends(currentFriends);
    return (friend: friend, allFriends: currentFriends);
  }

  /// フレンドを削除する（端末内のキャッシュからのみ削除）。
  Future<List<FriendProfile>> removeFriend(String friendCode) async {
    final friends = await loadFriends();
    friends.removeWhere((f) => f.friendCode == friendCode);
    await _saveFriends(friends);
    return friends;
  }

  int _pickColorForCode(String code) {
    const palette = [
      0xFF7B1FA2, // パープル
      0xFF00897B, // ティール
      0xFF3949AB, // インディゴ
      0xFFC2185B, // ピンク
      0xFF0277BD, // ライトブルー
    ];
    return palette[code.hashCode.abs() % palette.length];
  }
}

/// 体験用サンプルフレンド3人。実在の利用者ではなく、端末内だけで
/// 現在地周辺にピンを表示する。コード追加の検索対象にはならない。
class SampleFriends {
  static const List<({String code, String label})> presets = [
    (code: 'GM-1029', label: '🍜 メンマ先輩 (GM-1029)'),
    (code: 'GM-4410', label: '☕ カフェ巡り葵 (GM-4410)'),
    (code: 'GM-8831', label: '🥩 肉とスパイスの健 (GM-8831)'),
  ];

  static FriendProfile build(String code, LatLng baseLatLng) {
    final lat = baseLatLng.latitude;
    final lng = baseLatLng.longitude;
    final now = DateTime.now();

    switch (code) {
      case 'GM-1029':
        return FriendProfile(
          friendCode: 'GM-1029',
          displayName: 'メンマ先輩',
          avatarEmoji: '🍜',
          title: '👑 伝説のグルメ覇王',
          colorValue: 0xFF7B1FA2,
          syncedAt: now,
          isSample: true,
          records: [
            RestaurantRecord(
              id: 'friend_1029_1',
              name: '濃厚豚骨ラーメン 鶴亀',
              category: '🍜 ラーメン',
              latitude: lat + 0.00055,
              longitude: lng - 0.00035,
              chargeCount: 4,
              priceRange: '〜1,000円',
              goodPoints: const ['神コスパ', '味が最高', '提供が早い'],
              lastVisitedAt: now,
            ),
            RestaurantRecord(
              id: 'friend_1029_2',
              name: '町中華 龍星軒',
              category: '🥟 中華料理',
              latitude: lat - 0.00045,
              longitude: lng - 0.00050,
              chargeCount: 2,
              priceRange: '〜1,000円',
              goodPoints: const ['ボリューム満点', '1人でも入りやすい'],
              lastVisitedAt: now,
            ),
            RestaurantRecord(
              id: 'friend_1029_3',
              name: 'つけ麺 琥珀堂',
              category: '🍜 つけ麺',
              latitude: lat + 0.00015,
              longitude: lng + 0.00065,
              chargeCount: 1,
              priceRange: '1,000〜2,000円',
              goodPoints: const ['味が最高'],
              lastVisitedAt: now,
            ),
          ],
        );
      case 'GM-4410':
        return FriendProfile(
          friendCode: 'GM-4410',
          displayName: 'カフェ巡り葵',
          avatarEmoji: '☕',
          title: '🔥 街の常連マスター',
          colorValue: 0xFF00897B,
          syncedAt: now,
          isSample: true,
          records: [
            RestaurantRecord(
              id: 'friend_4410_1',
              name: '自家焙煎 珈琲美学',
              category: '☕ カフェ・喫茶',
              latitude: lat - 0.00058,
              longitude: lng + 0.00020,
              chargeCount: 3,
              priceRange: '〜1,000円',
              goodPoints: const ['雰囲気◎', '1人でも入りやすい', '味が最高'],
              lastVisitedAt: now,
            ),
            RestaurantRecord(
              id: 'friend_4410_2',
              name: '焼きたてベーカリー 麦の音',
              category: '🥐 パン・カフェ',
              latitude: lat + 0.00048,
              longitude: lng + 0.00052,
              chargeCount: 2,
              priceRange: '〜1,000円',
              goodPoints: const ['神コスパ', '提供が早い'],
              lastVisitedAt: now,
            ),
          ],
        );
      default: // GM-8831
        return FriendProfile(
          friendCode: 'GM-8831',
          displayName: '肉とスパイスの健',
          avatarEmoji: '🥩',
          title: '👑 伝説のグルメ覇王',
          colorValue: 0xFF3949AB,
          syncedAt: now,
          isSample: true,
          records: [
            RestaurantRecord(
              id: 'friend_8831_1',
              name: '炭火焼肉 ホルモン道場',
              category: '🥩 焼肉・ホルモン',
              latitude: lat - 0.00020,
              longitude: lng - 0.00068,
              chargeCount: 5,
              priceRange: '2,000円〜',
              goodPoints: const ['味が最高', 'ボリューム満点', '雰囲気◎'],
              lastVisitedAt: now,
            ),
            RestaurantRecord(
              id: 'friend_8831_2',
              name: 'スパイスカレー マハラジャ',
              category: '🍛 カレー',
              latitude: lat + 0.00065,
              longitude: lng + 0.00010,
              chargeCount: 2,
              priceRange: '1,000〜2,000円',
              goodPoints: const ['味が最高', '提供が早い'],
              lastVisitedAt: now,
            ),
          ],
        );
    }
  }
}
