import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend_profile.dart';
import '../models/restaurant_record.dart';
import 'share_service.dart';

/// ステップ⑦：Supabase連携によるフレンド機能・友達のマップ共有サービス
class FriendSupabaseService {
  static const String _myCodeKey = 'gourmet_map_my_friend_code_v1';
  static const String _friendsListKey = 'gourmet_map_friends_list_v1';
  static const String _supabaseUrlKey = 'gourmet_map_supabase_url_v1';
  static const String _supabaseAnonKeyKey = 'gourmet_map_supabase_anon_key_v1';

  /// Supabaseのテーブル名
  static const String tableName = 'shared_maps';

  /// Supabaseの接続情報（画面上の設定ダイアログからも変更・保存可能）
  static String supabaseUrl = '';
  static String supabaseAnonKey = '';

  static bool get isCloudConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Supabase SQL Editor用のテーブル作成SQLテンプレート
  static const String supabaseSetupSql = '''
create table if not exists public.shared_maps (
  friend_code text primary key,
  display_name text not null,
  avatar_emoji text default '🍴',
  title text default '',
  records_json jsonb not null default '[]'::jsonb,
  updated_at timestamptz default now()
);

alter table public.shared_maps enable row level security;

create policy "Allow public read shared_maps"
  on public.shared_maps for select using (true);

create policy "Allow public upsert shared_maps"
  on public.shared_maps for insert with check (true);

create policy "Allow public update shared_maps"
  on public.shared_maps for update using (true);
''';

  /// 初期化：保存済みのSupabase設定・自分のフレンドコード・フレンド一覧を読み込む
  Future<({String myCode, List<FriendProfile> friends})> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final savedUrl = prefs.getString(_supabaseUrlKey);
    final savedKey = prefs.getString(_supabaseAnonKeyKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      supabaseUrl = savedUrl;
    }
    if (savedKey != null && savedKey.isNotEmpty) {
      supabaseAnonKey = savedKey;
    }

    // 自分のフレンドコードを取得（未発行なら生成）
    String? myCode = prefs.getString(_myCodeKey);
    if (myCode == null || myCode.isEmpty) {
      final rand = Random();
      final numPart = 1000 + rand.nextInt(9000);
      myCode = 'GM-$numPart';
      await prefs.setString(_myCodeKey, myCode);
    }

    final friends = await loadFriends();
    return (myCode: myCode, friends: friends);
  }

  /// Supabase接続設定を保存
  Future<void> saveSupabaseCredentials({
    required String url,
    required String anonKey,
  }) async {
    supabaseUrl = url.trim();
    supabaseAnonKey = anonKey.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_supabaseUrlKey, supabaseUrl);
    await prefs.setString(_supabaseAnonKeyKey, supabaseAnonKey);
  }

  /// 動的SupabaseClientを生成
  SupabaseClient? _createClient() {
    if (!isCloudConfigured) return null;
    try {
      return SupabaseClient(supabaseUrl.trim(), supabaseAnonKey.trim());
    } catch (_) {
      return null;
    }
  }

  /// 保存済みのフレンドリストを読み込む
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

  /// 自分のマップデータをSupabaseクラウドへ同期（公開・更新）する
  Future<({bool syncedToCloud, String message})> syncMyMapToCloud({
    required String myFriendCode,
    required String userName,
    required List<RestaurantRecord> myRecords,
  }) async {
    final client = _createClient();
    final title = ShareService.calculateGourmetTitle(myRecords);

    if (client != null) {
      try {
        await client.from(tableName).upsert({
          'friend_code': myFriendCode,
          'display_name': userName,
          'avatar_emoji': '🔥',
          'title': title,
          'records_json': myRecords.map((r) => r.toJson()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        return (
          syncedToCloud: true,
          message: '☁️ Supabaseクラウドにあなたのマップ（${myRecords.length}店舗）を同期しました！',
        );
      } catch (e) {
        return (
          syncedToCloud: false,
          message: 'ローカル同期完了（※Supabase通信エラー: $e）',
        );
      }
    }

    return (
      syncedToCloud: false,
      message:
          '✅ フレンドコード [$myFriendCode] で共有準備OK！（Supabase設定でクラウド同期も有効化できます）',
    );
  }

  /// フレンドコードを指定して友達を追加・マップを取得する
  Future<({FriendProfile friend, List<FriendProfile> allFriends, bool fromCloud})>
      addFriendByCode({
    required String friendCodeInput,
    required LatLng baseLatLng,
  }) async {
    final normalizedCode = friendCodeInput.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw Exception('フレンドコードを入力してください');
    }

    final currentFriends = await loadFriends();
    FriendProfile? fetchedFriend;
    bool fromCloud = false;

    // 1. Supabaseが設定されていればクラウドDBから検索
    final client = _createClient();
    if (client != null) {
      try {
        final row = await client
            .from(tableName)
            .select()
            .eq('friend_code', normalizedCode)
            .maybeSingle();

        if (row != null) {
          final rawList = row['records_json'] as List<dynamic>? ?? [];
          final parsedRecords = rawList
              .map((e) => RestaurantRecord.fromJson(e as Map<String, dynamic>))
              .toList();

          fetchedFriend = FriendProfile(
            friendCode: normalizedCode,
            displayName: (row['display_name'] ?? 'グルメ友達').toString(),
            avatarEmoji: (row['avatar_emoji'] ?? '🍴').toString(),
            title: (row['title'] ?? '⚡ 爆速グルメハンター').toString(),
            colorValue: _pickColorForCode(normalizedCode),
            records: parsedRecords,
            syncedAt: DateTime.now(),
          );
          fromCloud = true;
        }
      } catch (_) {
        // クラウド未検出またはオフライン時はデモフレンド生成へフォールバック
      }
    }

    // 2. クラウドに該当がない場合、またはサンプルコードの場合は現在地周辺にデモフレンドを生成
    fetchedFriend ??= _generateDemoFriend(
      code: normalizedCode,
      baseLatLng: baseLatLng,
    );

    final existingIndex =
        currentFriends.indexWhere((f) => f.friendCode == normalizedCode);
    if (existingIndex != -1) {
      currentFriends[existingIndex] = fetchedFriend;
    } else {
      currentFriends.add(fetchedFriend);
    }

    await _saveFriends(currentFriends);
    return (
      friend: fetchedFriend,
      allFriends: currentFriends,
      fromCloud: fromCloud,
    );
  }

  /// フレンドを削除する
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

  /// 今すぐフレンドマップ共有を体験できる3人のプリセット友達＆カスタムコード生成
  FriendProfile _generateDemoFriend({
    required String code,
    required LatLng baseLatLng,
  }) {
    final lat = baseLatLng.latitude;
    final lng = baseLatLng.longitude;
    final now = DateTime.now();

    if (code == 'GM-1029') {
      return FriendProfile(
        friendCode: 'GM-1029',
        displayName: 'メンマ先輩',
        avatarEmoji: '🍜',
        title: '👑 伝説のグルメ覇王',
        colorValue: 0xFF7B1FA2, // パープル
        syncedAt: now,
        records: [
          RestaurantRecord(
            id: 'friend_1029_1',
            name: '濃厚豚骨ラーメン 鶴亀',
            category: '🍜 ラーメン',
            latitude: lat + 0.00055,
            longitude: lng - 0.00035,
            chargeCount: 4, // 金＋炎ピン
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
            chargeCount: 2, // 銀ピン
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
            chargeCount: 1, // 銅ピン
            priceRange: '1,000〜2,000円',
            goodPoints: const ['味が最高'],
            lastVisitedAt: now,
          ),
        ],
      );
    }

    if (code == 'GM-4410') {
      return FriendProfile(
        friendCode: 'GM-4410',
        displayName: 'カフェ巡り葵',
        avatarEmoji: '☕',
        title: '🔥 街の常連マスター',
        colorValue: 0xFF00897B, // ティールグリーン
        syncedAt: now,
        records: [
          RestaurantRecord(
            id: 'friend_4410_1',
            name: '自家焙煎 珈琲美学',
            category: '☕ カフェ・喫茶',
            latitude: lat - 0.00058,
            longitude: lng + 0.00020,
            chargeCount: 3, // 金＋炎ピン
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
            chargeCount: 2, // 銀ピン
            priceRange: '〜1,000円',
            goodPoints: const ['神コスパ', '提供が早い'],
            lastVisitedAt: now,
          ),
        ],
      );
    }

    if (code == 'GM-8831') {
      return FriendProfile(
        friendCode: 'GM-8831',
        displayName: '肉とスパイスの健',
        avatarEmoji: '🥩',
        title: '👑 伝説のグルメ覇王',
        colorValue: 0xFF3949AB, // インディゴブルー
        syncedAt: now,
        records: [
          RestaurantRecord(
            id: 'friend_8831_1',
            name: '炭火焼肉 ホルモン道場',
            category: '🥩 焼肉・ホルモン',
            latitude: lat - 0.00020,
            longitude: lng - 0.00068,
            chargeCount: 5, // 金＋炎ピン
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
            chargeCount: 2, // 銀ピン
            priceRange: '1,000〜2,000円',
            goodPoints: const ['味が最高', '提供が早い'],
            lastVisitedAt: now,
          ),
        ],
      );
    }

    // 任意のコードが入力された場合も、現在地周辺にフレンドを生成
    return FriendProfile(
      friendCode: code,
      displayName: 'グルメ仲間 ($code)',
      avatarEmoji: '🍻',
      title: '⚡ 爆速グルメハンター',
      colorValue: _pickColorForCode(code),
      syncedAt: now,
      records: [
        RestaurantRecord(
          id: 'friend_${code}_1',
          name: 'ビストロ 隠れ家キッチン',
          category: '🍷 洋食・ビストロ',
          latitude: lat + 0.00038,
          longitude: lng - 0.00042,
          chargeCount: 3,
          priceRange: '1,000〜2,000円',
          goodPoints: const ['雰囲気◎', '味が最高'],
          lastVisitedAt: now,
        ),
        RestaurantRecord(
          id: 'friend_${code}_2',
          name: '駅前大衆酒場 まるよし',
          category: '🏮 居酒屋・定食',
          latitude: lat - 0.00040,
          longitude: lng + 0.00030,
          chargeCount: 1,
          priceRange: '〜1,000円',
          goodPoints: const ['神コスパ', '提供が早い'],
          lastVisitedAt: now,
        ),
      ],
    );
  }
}

