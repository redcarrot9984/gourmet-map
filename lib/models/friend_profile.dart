import 'dart:convert';
import 'package:flutter/material.dart';
import 'restaurant_record.dart';

/// マップ上のピン表示フィルターモード
enum MapFilterMode {
  mineOnly, // 自分のピンのみ表示
  allWithFriends, // 自分＋全フレンドのピンを重ねて表示
  singleFriend, // 特定のフレンド1人のピンを表示
}

/// ステップ⑦：フレンドのプロフィール＆共有マップデータモデル
class FriendProfile {
  final String friendCode; // 例: "GM-1029"
  final String displayName; // 例: "メンマ先輩"
  final String avatarEmoji; // 例: "🍜"
  final String title; // 例: "🔥 街の常連マスター"
  final int colorValue; // 識別用テーマカラー
  final List<RestaurantRecord> records; // フレンドの登録店舗リスト
  final DateTime syncedAt;
  final bool isSample; // 体験用サンプル（実在の利用者ではない）かどうか
  final int cardThemeIndex; // 名刺テーマ（フレンドの名刺表示用）

  const FriendProfile({
    required this.friendCode,
    required this.displayName,
    required this.avatarEmoji,
    required this.title,
    required this.colorValue,
    required this.records,
    required this.syncedAt,
    this.isSample = false,
    this.cardThemeIndex = 0,
  });

  Color get themeColor => Color(colorValue);

  int get totalCharges =>
      records.fold<int>(0, (sum, item) => sum + item.chargeCount);

  int get goldPinCount => records.where((r) => r.chargeCount >= 3).length;

  FriendProfile copyWith({
    String? friendCode,
    String? displayName,
    String? avatarEmoji,
    String? title,
    int? colorValue,
    List<RestaurantRecord>? records,
    DateTime? syncedAt,
    bool? isSample,
    int? cardThemeIndex,
  }) {
    return FriendProfile(
      friendCode: friendCode ?? this.friendCode,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      title: title ?? this.title,
      colorValue: colorValue ?? this.colorValue,
      records: records ?? this.records,
      syncedAt: syncedAt ?? this.syncedAt,
      isSample: isSample ?? this.isSample,
      cardThemeIndex: cardThemeIndex ?? this.cardThemeIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friendCode': friendCode,
      'displayName': displayName,
      'avatarEmoji': avatarEmoji,
      'title': title,
      'colorValue': colorValue,
      'records': records.map((r) => r.toJson()).toList(),
      'syncedAt': syncedAt.toIso8601String(),
      'isSample': isSample,
      'cardThemeIndex': cardThemeIndex,
    };
  }

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as List<dynamic>? ?? [];
    return FriendProfile(
      friendCode: (json['friendCode'] as String?) ?? 'GM-0000',
      displayName: (json['displayName'] as String?) ?? 'グルメ友達',
      avatarEmoji: (json['avatarEmoji'] as String?) ?? '🍴',
      title: (json['title'] as String?) ?? '⚡ 爆速グルメハンター',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF7B1FA2,
      records: rawRecords
          .map((e) => RestaurantRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      syncedAt: json['syncedAt'] != null
          ? DateTime.tryParse(json['syncedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSample: (json['isSample'] as bool?) ?? false,
      cardThemeIndex: (json['cardThemeIndex'] as num?)?.toInt() ?? 0,
    );
  }

  /// 管理画面向けの並び順：実在のフレンドを先に、店舗数の多い順、
  /// サンプルは最後にまとめる。
  static List<FriendProfile> sortedForDisplay(List<FriendProfile> friends) {
    final sorted = [...friends];
    sorted.sort((a, b) {
      if (a.isSample != b.isSample) return a.isSample ? 1 : -1;
      final byCount = b.records.length.compareTo(a.records.length);
      if (byCount != 0) return byCount;
      return a.displayName.compareTo(b.displayName);
    });
    return sorted;
  }

  /// 名前・フレンドコードでの絞り込み（大文字小文字は区別しない）。
  static List<FriendProfile> filterByQuery(
    List<FriendProfile> friends,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return friends;
    return friends
        .where(
          (f) =>
              f.displayName.toLowerCase().contains(q) ||
              f.friendCode.toLowerCase().contains(q),
        )
        .toList();
  }

  static String encodeList(List<FriendProfile> friends) {
    return jsonEncode(friends.map((f) => f.toJson()).toList());
  }

  static List<FriendProfile> decodeList(String jsonStr) {
    final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
    return decoded
        .map((e) => FriendProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
