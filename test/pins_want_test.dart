import 'package:flutter_test/flutter_test.dart';
import 'package:gourmet_map/models/friend_profile.dart';
import 'package:gourmet_map/models/restaurant_record.dart';
import 'package:gourmet_map/models/want_to_visit.dart';
import 'package:gourmet_map/utils/pin_grouping.dart';
import 'package:gourmet_map/utils/place_match.dart';

RestaurantRecord rec(String id, double lat, double lng, {String name = '店'}) {
  return RestaurantRecord(
    id: id,
    name: name,
    category: '🍜 ラーメン',
    latitude: lat,
    longitude: lng,
    chargeCount: 1,
    priceRange: '〜1,000円',
    goodPoints: const [],
    lastVisitedAt: DateTime(2026, 11, 6),
  );
}

FriendProfile friend(String code) {
  return FriendProfile(
    friendCode: code,
    displayName: '友達',
    avatarEmoji: '🍜',
    title: '称号',
    colorValue: 0xFF7B1FA2,
    records: const [],
    syncedAt: DateTime(2026, 11, 6),
  );
}

void main() {
  // 岡山駅付近の座標
  const lat = 34.66641;
  const lng = 133.91835;

  group('PlaceMatch', () {
    test('同座標は同一地点、約200m離れると別地点', () {
      expect(PlaceMatch.isSamePlace(lat, lng, lat, lng), isTrue);
      // 緯度 +0.0018 ≈ 約200m
      expect(PlaceMatch.isSamePlace(lat, lng, lat + 0.0018, lng), isFalse);
      // 緯度 +0.00027 ≈ 約30m
      expect(PlaceMatch.isSamePlace(lat, lng, lat + 0.00027, lng), isTrue);
    });

    test('店名の類似判定（空白・部分一致）', () {
      expect(PlaceMatch.nameSimilar('絶品 ラーメン店', '絶品ラーメン店'), isTrue);
      expect(PlaceMatch.nameSimilar('ラーメン店', '絶品ラーメン店'), isTrue);
      expect(PlaceMatch.nameSimilar('ラーメン店', 'うどん店'), isFalse);
      expect(PlaceMatch.nameSimilar('', '店'), isFalse);
    });

    test('matches は距離と店名の両方が必要', () {
      expect(
        PlaceMatch.matches(
          lat: lat,
          lng: lng,
          name: '絶品ラーメン店',
          otherLat: lat,
          otherLng: lng,
          otherName: '絶品 ラーメン店',
        ),
        isTrue,
      );
      // 同じ場所でも名前が違えば一致しない（隣の店を誤判定しない）
      expect(
        PlaceMatch.matches(
          lat: lat,
          lng: lng,
          name: 'ラーメン店',
          otherLat: lat,
          otherLng: lng,
          otherName: 'うどん店',
        ),
        isFalse,
      );
    });
  });

  group('groupPins (F1)', () {
    test('自分とフレンドの同地点ピンが1グループに合体する', () {
      final groups = groupPins([
        PinEntry(record: rec('mine1', lat, lng)),
        PinEntry(record: rec('f1', lat, lng), friend: friend('GM-AAAAA-AAAAA')),
        PinEntry(record: rec('f2', lat + 0.01, lng)), // 約1.1km先
      ]);
      expect(groups.length, 2);
      final merged = groups.firstWhere((g) => g.isMerged);
      expect(merged.entries.length, 2);
      expect(merged.hasMine, isTrue);
    });

    test('離れたピンは合体しない', () {
      final groups = groupPins([
        PinEntry(record: rec('a', lat, lng)),
        PinEntry(record: rec('b', lat + 0.002, lng)), // 約220m
      ]);
      expect(groups.length, 2);
      expect(groups.every((g) => !g.isMerged), isTrue);
    });
  });

  group('clustering (F2)', () {
    test('ズーム15未満でのみ有効', () {
      expect(clusteringEnabled(14.9), isTrue);
      expect(clusteringEnabled(15), isFalse);
      expect(clusteringEnabled(16), isFalse);
    });

    test('大きなセルでは近いグループが1セルに集約される', () {
      final groups = groupPins([
        PinEntry(record: rec('a', lat, lng)),
        PinEntry(record: rec('b', lat + 0.005, lng + 0.005)),
        PinEntry(record: rec('c', lat + 0.2, lng + 0.2)),
      ]);
      final cells = clusterGroups(groups, 0.05);
      expect(cells.length, 2);
      expect(cells.any((cell) => cell.length == 2), isTrue);
    });
  });

  group('WantToVisit (N1)', () {
    test('JSON往復で全項目が保持される', () {
      final want = WantToVisit(
        id: 'w1',
        name: '行きたい店',
        category: '☕ カフェ・喫茶',
        latitude: lat,
        longitude: lng,
        source: WantSource.friend,
        sourceLabel: 'メンマ先輩',
        createdAt: DateTime(2026, 11, 6, 12, 30),
      );
      final restored = WantToVisit.fromJson(want.toJson());
      expect(restored.id, 'w1');
      expect(restored.name, '行きたい店');
      expect(restored.source, WantSource.friend);
      expect(restored.sourceLabel, 'メンマ先輩');
      expect(restored.source.label, 'フレンドのおすすめ');
      expect(restored.createdAt, DateTime(2026, 11, 6, 12, 30));
    });

    test('encodeList/decodeList の往復', () {
      final wants = [
        WantToVisit(
          id: 'w1',
          name: 'A',
          category: '🍽 その他',
          latitude: lat,
          longitude: lng,
          source: WantSource.map,
          createdAt: DateTime(2026, 11, 6),
        ),
      ];
      final restored = WantToVisit.decodeList(WantToVisit.encodeList(wants));
      expect(restored.length, 1);
      expect(restored.first.source, WantSource.map);
    });
  });
}
