import 'package:flutter_test/flutter_test.dart';
import 'package:gourmet_map/models/restaurant_record.dart';
import 'package:gourmet_map/models/shared_record.dart';
import 'package:gourmet_map/services/restaurant_search_service.dart';
import 'package:gourmet_map/services/share_service.dart';

RestaurantRecord rec(int count, {String comment = '', bool isShared = true}) {
  return RestaurantRecord(
    id: 'r$count',
    name: '店$count',
    category: '🍜 ラーメン',
    latitude: 34.66641,
    longitude: 133.91835,
    chargeCount: count,
    priceRange: '〜1,000円',
    goodPoints: const [],
    lastVisitedAt: DateTime(2026, 11, 6),
    comment: comment,
    isShared: isShared,
  );
}

NearbyCandidate cand(String id, String name, double lat, double lng, int dist) {
  return NearbyCandidate(
    id: id,
    name: name,
    category: '🍴 飲食店',
    latitude: lat,
    longitude: lng,
    distanceMeters: dist,
    address: '',
    isMock: false,
  );
}

void main() {
  group('ランク階段', () {
    test('回数ごとにランク名が上がる', () {
      expect(rec(1).rankTitle, contains('BRONZE'));
      expect(rec(2).rankTitle, contains('SILVER'));
      expect(rec(3).rankTitle, contains('GOLD'));
      expect(rec(4).rankTitle, contains('PLATINUM'));
      expect(rec(5).rankTitle, contains('LEGEND'));
      expect(rec(7).rankTitle, contains('DIAMOND'));
      expect(rec(10).rankTitle, contains('RAINBOW'));
    });
  });

  group('コメント・共有フラグ', () {
    test('JSON往復で保持される', () {
      final r = rec(2, comment: '麺がうまい', isShared: false);
      final restored = RestaurantRecord.fromJson(r.toJson());
      expect(restored.comment, '麺がうまい');
      expect(restored.isShared, isFalse);
    });

    test('旧形式JSON（キーなし）でも既定値で読める', () {
      final legacy = rec(1).toJson()
        ..remove('comment')
        ..remove('isShared');
      final restored = RestaurantRecord.fromJson(legacy);
      expect(restored.comment, '');
      expect(restored.isShared, isTrue);
    });

    test('共有ペイロードにコメントが入り、往復する', () {
      final shared = SharedRecord.fromRecord(rec(1, comment: 'おすすめ'));
      expect(shared.comment, 'おすすめ');
      final restored = SharedRecord.fromJson(shared.toJson());
      expect(restored.comment, 'おすすめ');
      expect(restored.toRestaurantRecord(receivedAt: DateTime(2026)).comment,
          'おすすめ');
    });
  });

  group('検索の重複排除', () {
    const lat = 34.66641;
    const lng = 133.91835;

    test('同じIDは1件になる', () {
      final result = RestaurantSearchService.dedupeCandidates([
        cand('a', 'ラーメン店', lat, lng, 50),
        cand('a', 'ラーメン店', lat, lng, 80),
      ]);
      expect(result.length, 1);
      expect(result.first.distanceMeters, 50);
    });

    test('同名・至近の重複は近い方だけ残る', () {
      final result = RestaurantSearchService.dedupeCandidates([
        cand('a', '絶品ラーメン', lat, lng, 90),
        cand('b', '絶品ラーメン', lat + 0.0001, lng, 30),
        cand('c', 'うどん店', lat, lng, 40), // 同じ場所でも別名は残す
        cand('d', '絶品ラーメン', lat + 0.01, lng, 120), // 遠い同名店は残す
      ]);
      expect(result.length, 3);
      expect(result.map((c) => c.id), containsAll(['b', 'c', 'd']));
    });
  });

  group('称号の階段', () {
    test('実績に応じて称号が上がる', () {
      expect(ShareService.calculateGourmetTitle([]), contains('駆け出し'));
      expect(
        ShareService.calculateGourmetTitle([rec(1)]),
        contains('開拓者'),
      );
      expect(
        ShareService.calculateGourmetTitle([rec(3), rec(3), rec(3)]),
        contains('伝説のグルメ覇王'),
      );
      expect(
        ShareService.calculateGourmetTitle([rec(7), rec(7)]),
        contains('グルメ界の頂点'),
      );
    });
  });
}
