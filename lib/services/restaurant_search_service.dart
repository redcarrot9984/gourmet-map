import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/restaurant_record.dart';

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
          return apiResults;
        }
      } catch (_) {
        // APIエラー時・通信オフライン時はモックデータにフォールバックして確実に動作を継続
      }
    }

    // モックモード時（または周辺に店舗がない場合のフォールバック）は架空の飲食店3件を自動生成
    return _generateMockCandidates(latitude: latitude, longitude: longitude);
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
