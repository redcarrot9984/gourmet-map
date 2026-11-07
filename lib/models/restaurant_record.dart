import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// ステップ④：現在地周辺の飲食店候補モデル
class NearbyCandidate {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final String address;
  final bool isMock;

  const NearbyCandidate({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.address = '',
    this.isMock = true,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

/// ステップ⑤：登録された飲食店＆リピートチャージ記録モデル
class RestaurantRecord {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final int chargeCount; // 来店チャージ回数（1:銅, 2:銀, 3以上:金+炎）
  final String priceRange; // 「〜1,000円」「1,000〜2,000円」「2,000円〜」
  final List<String> goodPoints; // 「神コスパ」「味が最高」など
  final String? imagePath; // 撮影した写真のローカルパス
  final String? imageBase64; // クロスプラットフォーム用Base64画像データ
  final DateTime lastVisitedAt;
  final String comment; // 一言コメント（フレンドにも共有される）
  final bool isShared; // フレンドへ共有するかどうか（店ごとのON/OFF）

  const RestaurantRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.chargeCount,
    required this.priceRange,
    required this.goodPoints,
    this.imagePath,
    this.imageBase64,
    required this.lastVisitedAt,
    this.comment = '',
    this.isShared = true,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  /// ピンのランク名称を取得。
  /// ランクアップの間隔は広めに取る（2回・10回・20回・30回・50回・100回）。
  String get rankTitle {
    if (chargeCount >= 100) return '🌈 神の常連 (RAINBOW)';
    if (chargeCount >= 50) return '💎 ダイヤ常連 (DIAMOND)';
    if (chargeCount >= 30) return '👑 殿堂レジェンド (LEGEND)';
    if (chargeCount >= 20) return '🔷 プラチナ常連 (PLATINUM)';
    if (chargeCount >= 10) return '🔥 常連レジェンド (GOLD)';
    if (chargeCount >= 2) return '✨ リピーター (SILVER)';
    return '🍴 初訪問 (BRONZE)';
  }

  /// 次のランクまでの目安（登録シートのバッジ表示用）。
  static String nextRankHint(int currentCount) {
    if (currentCount <= 0) return '初訪問 (銅へ)';
    if (currentCount == 1) return '現在1回 → 2回で銀へ⚡';
    if (currentCount < 10) return '現在$currentCount回 → 10回で金へ🔥';
    if (currentCount < 20) return '現在$currentCount回 → 20回でプラチナへ🔷';
    if (currentCount < 30) return '現在$currentCount回 → 30回で殿堂へ👑';
    if (currentCount < 50) return '現在$currentCount回 → 50回でダイヤへ💎';
    if (currentCount < 100) return '現在$currentCount回 → 100回で虹へ🌈';
    return '🌈 神の常連';
  }

  RestaurantRecord copyWith({
    String? id,
    String? name,
    String? category,
    double? latitude,
    double? longitude,
    int? chargeCount,
    String? priceRange,
    List<String>? goodPoints,
    String? imagePath,
    String? imageBase64,
    DateTime? lastVisitedAt,
    String? comment,
    bool? isShared,
  }) {
    return RestaurantRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      chargeCount: chargeCount ?? this.chargeCount,
      priceRange: priceRange ?? this.priceRange,
      goodPoints: goodPoints ?? this.goodPoints,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
      comment: comment ?? this.comment,
      isShared: isShared ?? this.isShared,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'chargeCount': chargeCount,
      'priceRange': priceRange,
      'goodPoints': goodPoints,
      'imagePath': imagePath,
      'imageBase64': imageBase64,
      'lastVisitedAt': lastVisitedAt.toIso8601String(),
      'comment': comment,
      'isShared': isShared,
    };
  }

  factory RestaurantRecord.fromJson(Map<String, dynamic> json) {
    return RestaurantRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      category: (json['category'] as String?) ?? '飲食店',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      chargeCount: (json['chargeCount'] as num?)?.toInt() ?? 1,
      priceRange: (json['priceRange'] as String?) ?? '〜1,000円',
      goodPoints: (json['goodPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      imagePath: json['imagePath'] as String?,
      imageBase64: json['imageBase64'] as String?,
      lastVisitedAt: json['lastVisitedAt'] != null
          ? DateTime.tryParse(json['lastVisitedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      comment: (json['comment'] as String?) ?? '',
      isShared: (json['isShared'] as bool?) ?? true,
    );
  }

  static String encodeList(List<RestaurantRecord> records) {
    return jsonEncode(records.map((r) => r.toJson()).toList());
  }

  static List<RestaurantRecord> decodeList(String jsonString) {
    final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
    return decoded
        .map((item) => RestaurantRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
