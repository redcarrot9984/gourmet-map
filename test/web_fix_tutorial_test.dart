import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gourmet_map/models/restaurant_record.dart';
import 'package:gourmet_map/services/restaurant_search_service.dart';
import 'package:gourmet_map/services/storage_service.dart';
import 'package:gourmet_map/widgets/tutorial_sheet.dart';

NearbyCandidate candidate({
  required String id,
  required String name,
  required double lat,
  required int distance,
  String address = '',
}) {
  return NearbyCandidate(
    id: id,
    name: name,
    category: '🍴 飲食店',
    latitude: lat,
    longitude: 133.0,
    distanceMeters: distance,
    address: address,
    isMock: false,
  );
}

void main() {
  group('重複排除の強化', () {
    test('似た店名で50mなら重複として除く（従来は残っていた）', () {
      final result = RestaurantSearchService.dedupeCandidates([
        candidate(id: 'a', name: '麺屋 一番', lat: 34.0000, distance: 10),
        candidate(id: 'b', name: '麺屋一番', lat: 34.00045, distance: 50),
      ]);
      expect(result.length, 1);
      expect(result.first.id, 'a');
    });

    test('完全一致の店名で120mなら重複として除く（入口違い）', () {
      final result = RestaurantSearchService.dedupeCandidates([
        candidate(id: 'a', name: 'カフェ空', lat: 34.0000, distance: 10),
        candidate(id: 'b', name: 'カフェ 空', lat: 34.0011, distance: 120),
      ]);
      expect(result.length, 1);
    });

    test('住所が同じで店名が似ていれば180mでも重複として除く', () {
      final result = RestaurantSearchService.dedupeCandidates([
        candidate(
          id: 'a',
          name: 'ひまわり食堂',
          lat: 34.0000,
          distance: 10,
          address: '岡山市北区本町1-1',
        ),
        candidate(
          id: 'b',
          name: 'ひまわり食堂 本町店',
          lat: 34.0016,
          distance: 180,
          address: '岡山市北区本町1-1',
        ),
      ]);
      expect(result.length, 1);
    });

    test('別の店は近くても残る', () {
      final result = RestaurantSearchService.dedupeCandidates([
        candidate(id: 'a', name: '麺屋 一番', lat: 34.0000, distance: 10),
        candidate(id: 'b', name: '寿司 海', lat: 34.0003, distance: 33),
        candidate(id: 'c', name: 'カフェ空', lat: 34.0020, distance: 220),
      ]);
      expect(result.length, 3);
    });
  });

  group('チュートリアル表示フラグ', () {
    test('未表示はfalse、保存後はtrue', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      expect(await storage.loadHasSeenTutorial(), isFalse);
      await storage.saveHasSeenTutorial();
      expect(await storage.loadHasSeenTutorial(), isTrue);
    });
  });

  group('チュートリアル画面', () {
    testWidgets('1ページ目が表示され、次へで進める', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TutorialSheet())),
      );
      expect(find.text('お店を記録して、自分の地図を作ろう'), findsOneWidget);
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
      expect(find.text('来店のたびに「チャージ」'), findsOneWidget);
    });
  });
}
