import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/restaurant_record.dart';
import '../utils/place_match.dart';

/// ステップ④：現在地周辺の飲食店候補を検索するサービスクラス
/// Yahoo!ローカルサーチAPI (YOLP) と モック自動生成 の切り替えに対応
class RestaurantSearchService {
  /// Yahoo! JAPAN デベロッパーネットワークの Client ID (AppID)
  static String yahooAppId =
      'dmVyPTIwMjUwNyZpZD1qd0l4ODBMNVNRJmhhc2g9WVRNM05qQmtZalJsTURGak1tWTNNdw';

  /// 手動でモックモードに固定したい場合のフラグ
  static bool forceMockMode = false;

  /// モックモードで動作中かどうか
  static bool get isMockMode => forceMockMode || yahooAppId.trim().isEmpty;

  /// 現在地 (latitude, longitude) から周辺の飲食店候補を取得
  Future<List<NearbyCandidate>> searchNearbyRestaurants({
    required double latitude,
    required double longitude,
    int radiusMeters = 150,
  }) async {
    // Web版：Yahoo! APIはブラウザのCORS制限で直接呼べないため、
    // CORS対応の Overpass API（OpenStreetMap）から周辺店舗を取得する
    if (kIsWeb && !forceMockMode) {
      try {
        var results = await _fetchFromOverpass(
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
        );
        if (results.isEmpty && radiusMeters < 800) {
          results = await _fetchFromOverpass(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: 800,
          );
        }
        if (results.isNotEmpty) {
          return dedupeCandidates(results);
        }
      } catch (_) {
        // 失敗時はモックへフォールバック
      }
      return _generateMockCandidates(latitude: latitude, longitude: longitude);
    }

    // AppIDが設定されており、強制モックモードでない場合はYahoo!ローカルサーチAPIを呼び出す
    if (!isMockMode) {
      try {
        // まず指定半径（デフォルト150m）で検索
        var apiResults = await _fetchFromYahooLocalSearch(
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
        );

        // 住宅街などで半径150m以内に飲食店が0件だった場合は、半径800mまで広げて再検索
        if (apiResults.isEmpty && radiusMeters < 800) {
          apiResults = await _fetchFromYahooLocalSearch(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: 800,
          );
        }

        if (apiResults.isNotEmpty) {
          return dedupeCandidates(apiResults);
        }
      } catch (_) {
        // APIエラー時・通信オフライン時はモックデータにフォールバックして確実に動作を継続
      }
    }

    // モックモード時（または周辺に店舗がない場合のフォールバック）は架空の飲食店3件を自動生成
    return _generateMockCandidates(latitude: latitude, longitude: longitude);
  }

  /// 検索結果の重複を除く（距離が近い方を残し、距離順に返す）。
  /// APIが同じ店を複数の入口座標や表記ゆれで返すことがあるため、
  /// 次のいずれかに当てはまれば重複とみなす：
  /// - 同じID
  /// - 店名が似ていて 60m 以内
  /// - 店名が完全一致（表記ゆれ除去後）で 150m 以内
  /// - 住所が同じで店名が似ていて 200m 以内
  static List<NearbyCandidate> dedupeCandidates(
    List<NearbyCandidate> input,
  ) {
    final sorted = [...input]
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    final result = <NearbyCandidate>[];
    final seenIds = <String>{};
    for (final candidate in sorted) {
      if (candidate.id.isNotEmpty && !seenIds.add(candidate.id)) {
        continue; // 同じIDは重複
      }
      final isDuplicate = result.any((kept) {
        final meters = PlaceMatch.metersBetween(
          candidate.latitude,
          candidate.longitude,
          kept.latitude,
          kept.longitude,
        );
        if (PlaceMatch.nameSimilar(candidate.name, kept.name) && meters <= 60) {
          return true;
        }
        if (PlaceMatch.normalizeName(candidate.name) ==
                PlaceMatch.normalizeName(kept.name) &&
            meters <= 150) {
          return true;
        }
        if (candidate.address.isNotEmpty &&
            candidate.address == kept.address &&
            PlaceMatch.nameSimilar(candidate.name, kept.name) &&
            meters <= 200) {
          return true;
        }
        return false;
      });
      if (!isDuplicate) {
        result.add(candidate);
      }
    }
    return result;
  }

  /// Web版向け：Overpass API（OpenStreetMap）から周辺の飲食店を取得する。
  /// ブラウザから直接呼べる（CORS対応）ため、Web版ではこちらを使う。
  Future<List<NearbyCandidate>> _fetchFromOverpass({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    const amenityLabels = {
      'restaurant': '🍴 飲食店',
      'cafe': '☕ カフェ・喫茶',
      'fast_food': '🍔 ファストフード',
      'food_court': '🍴 フードコート',
      'bakery': '🥐 ベーカリー',
      'bar': '🍺 バー・居酒屋',
      'pub': '🍺 バー・居酒屋',
      'ice_cream': '🍨 アイスクリーム',
    };
    final query = '''
[out:json][timeout:15];
(
  node["amenity"~"restaurant|cafe|fast_food|food_court|bakery|bar|pub|ice_cream"]["name"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"~"restaurant|cafe|fast_food|food_court"]["name"](around:$radiusMeters,$latitude,$longitude);
);
out center 40;
''';
    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: {'data': query},
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Overpass API error: ${response.statusCode}');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];
    const distanceCalc = Distance();
    final userPoint = LatLng(latitude, longitude);
    final candidates = <NearbyCandidate>[];
    for (final raw in elements) {
      final element = raw as Map<String, dynamic>;
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final name = (tags['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final center = element['center'] as Map<String, dynamic>?;
      final lat = (element['lat'] as num?)?.toDouble() ??
          (center?['lat'] as num?)?.toDouble();
      final lon = (element['lon'] as num?)?.toDouble() ??
          (center?['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final amenity = (tags['amenity'] ?? 'restaurant').toString();
      candidates.add(
        NearbyCandidate(
          id: 'osm_${element['type']}_${element['id']}',
          name: name,
          category: amenityLabels[amenity] ?? '🍴 飲食店',
          latitude: lat,
          longitude: lon,
          distanceMeters: distanceCalc
              .as(LengthUnit.Meter, userPoint, LatLng(lat, lon))
              .round(),
          address: '',
          isMock: false,
        ),
      );
    }
    return candidates;
  }

  /// Yahoo!ローカルサーチAPI (YOLP) から周辺の飲食店を取得
  Future<List<NearbyCandidate>> _fetchFromYahooLocalSearch({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    // YOLPのdistパラメータはkm単位（100m = 0.1km）
    final distKm = (radiusMeters / 1000.0).clamp(0.05, 3.0);

    final uri = Uri.parse(
      'https://map.yahooapis.jp/search/local/V1/localSearch',
    ).replace(
      queryParameters: {
        'appid': yahooAppId.trim(),
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'dist': distKm.toString(),
        'gc': '01', // 01 = グルメ・飲食店カテゴリ
        'results': '8',
        'sort': 'dist', // 現在地から近い順
        'output': 'json',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('YOLP API Error: ${response.statusCode}');
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final features = data['Feature'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      return [];
    }

    const distanceCalc = Distance();
    final userPoint = LatLng(latitude, longitude);
    final List<NearbyCandidate> candidates = [];

    for (final item in features) {
      final feature = item as Map<String, dynamic>;
      final id = (feature['Gid'] ?? feature['Id'] ?? '').toString();
      final name = (feature['Name'] ?? '名称不明の店舗').toString();

      // Geometry.Coordinates は "経度,緯度" の形式
      final geometry = feature['Geometry'] as Map<String, dynamic>?;
      final coordsStr = (geometry?['Coordinates'] ?? '').toString();
      final parts = coordsStr.split(',');
      if (parts.length < 2) continue;

      final lon = double.tryParse(parts[0]) ?? longitude;
      final lat = double.tryParse(parts[1]) ?? latitude;

      final property = feature['Property'] as Map<String, dynamic>?;
      final address = (property?['Address'] ?? '').toString();
      final genres = property?['Genre'] as List<dynamic>?;
      final rawCategory = (genres != null && genres.isNotEmpty)
          ? ((genres.first as Map<String, dynamic>)['Name'] ?? '飲食店').toString()
          : '飲食店';

      final distMeters = distanceCalc
          .as(LengthUnit.Meter, userPoint, LatLng(lat, lon))
          .round();

      candidates.add(
        NearbyCandidate(
          id: id.isEmpty ? name : id,
          name: name,
          category: '🍴 $rawCategory',
          latitude: lat,
          longitude: lon,
          distanceMeters: distMeters,
          address: address,
          isMock: false,
        ),
      );
    }

    return candidates;
  }

  /// 現在地のすぐ近く（半径35m〜82m圏内）に架空の飲食店3件を自動生成するモック機能
  List<NearbyCandidate> _generateMockCandidates({
    required double latitude,
    required double longitude,
  }) {
    return [
      NearbyCandidate(
        id: 'mock_ramen',
        name: '絶品ラーメン店',
        category: '🍜 ラーメン',
        latitude: latitude + 0.00025,
        longitude: longitude + 0.00022,
        distanceMeters: 35,
        address: '現在地から北東 35m',
        isMock: true,
      ),
      NearbyCandidate(
        id: 'mock_cafe',
        name: '駅前カフェ',
        category: '☕ カフェ・喫茶',
        latitude: latitude - 0.00032,
        longitude: longitude + 0.00042,
        distanceMeters: 58,
        address: '現在地から南東 58m',
        isMock: true,
      ),
      NearbyCandidate(
        id: 'mock_curry',
        name: '隠れ家カレー',
        category: '🍛 カレー・スパイス',
        latitude: latitude + 0.00040,
        longitude: longitude - 0.00052,
        distanceMeters: 82,
        address: '現在地から北西 82m',
        isMock: true,
      ),
    ];
  }
}
