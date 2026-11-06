import 'dart:convert';

import 'package:latlong2/latlong.dart';

/// N1：「行きたい店」の登録ソース。
enum WantSource {
  search, // 店舗検索の結果から
  map, // 地図の長押しから
  friend, // フレンドの店から（N2）
}

extension WantSourceLabel on WantSource {
  String get label {
    switch (this) {
      case WantSource.search:
        return '検索から追加';
      case WantSource.map:
        return '地図から追加';
      case WantSource.friend:
        return 'フレンドのおすすめ';
    }
  }
}

/// N1：行ってみたい店のモデル。実際に訪問して通常登録すると卒業する。
class WantToVisit {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final WantSource source;
  final String? sourceLabel; // フレンド名など
  final DateTime createdAt;

  const WantToVisit({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.sourceLabel,
    required this.createdAt,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'source': source.name,
      'sourceLabel': sourceLabel,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WantToVisit.fromJson(Map<String, dynamic> json) {
    return WantToVisit(
      id: json['id'] as String,
      name: json['name'] as String,
      category: (json['category'] as String?) ?? '🍽 その他',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      source: WantSource.values.firstWhere(
        (s) => s.name == (json['source'] as String?),
        orElse: () => WantSource.map,
      ),
      sourceLabel: json['sourceLabel'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static String encodeList(List<WantToVisit> wants) {
    return jsonEncode(wants.map((w) => w.toJson()).toList());
  }

  static List<WantToVisit> decodeList(String jsonStr) {
    final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
    return decoded
        .map((e) => WantToVisit.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
