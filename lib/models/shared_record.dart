import 'restaurant_record.dart';

/// フレンド機能 v2 でクラウドに共有する店舗データの形式。
///
/// 共有するのは以下の項目だけに絞る：
/// id / name / category / latitude / longitude / chargeCount / priceRange / goodPoints
///
/// 写真（imageBase64 / imagePath）と最終訪問日時（lastVisitedAt）は共有しない。
/// 漏えい時の被害と転送量を抑えるため。受信側では訪問日時を「受信した時刻」で
/// 補完して [RestaurantRecord] に戻す。
class SharedRecord {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final int chargeCount;
  final String priceRange;
  final List<String> goodPoints;

  const SharedRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.chargeCount,
    required this.priceRange,
    required this.goodPoints,
  });

  /// ローカルの店舗記録から共有形式へ変換する（写真・訪問日時は落とす）。
  factory SharedRecord.fromRecord(RestaurantRecord record) {
    return SharedRecord(
      id: record.id,
      name: record.name,
      category: record.category,
      latitude: record.latitude,
      longitude: record.longitude,
      chargeCount: record.chargeCount,
      priceRange: record.priceRange,
      goodPoints: record.goodPoints,
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
    };
  }

  factory SharedRecord.fromJson(Map<String, dynamic> json) {
    return SharedRecord(
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
    );
  }

  /// 受信側で表示用モデルに戻す。写真は常に無し、訪問日時は受信時刻で補完。
  RestaurantRecord toRestaurantRecord({required DateTime receivedAt}) {
    return RestaurantRecord(
      id: id,
      name: name,
      category: category,
      latitude: latitude,
      longitude: longitude,
      chargeCount: chargeCount,
      priceRange: priceRange,
      goodPoints: goodPoints,
      imagePath: null,
      imageBase64: null,
      lastVisitedAt: receivedAt,
    );
  }
}
