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

  const FriendProfile({
    required this.friendCode,
    required this.displayName,
    required this.avatarEmoji,
    required this.title,
    required this.colorValue,
    required this.records,
    required this.syncedAt,
    this.isSample = false,
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
    );
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
