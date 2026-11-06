import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gourmet_map/models/friend_code.dart';
import 'package:gourmet_map/models/friend_profile.dart';
import 'package:gourmet_map/models/restaurant_record.dart';
import 'package:gourmet_map/models/shared_record.dart';

void main() {
  group('FriendCode.generate', () {
    test('GM-XXXXX-XXXXX 形式で生成される', () {
      for (var i = 0; i < 200; i++) {
        final code = FriendCode.generate(Random(i));
        expect(FriendCode.isValidFormat(code), isTrue, reason: code);
        expect(code.length, 14); // 'GM-' + 5 + '-' + 5
      }
    });

    test('紛らわしい文字 0/O/1/I を含まない', () {
      for (var i = 0; i < 200; i++) {
        final code = FriendCode.generate(Random(1000 + i));
        for (final banned in ['0', 'O', '1', 'I']) {
          expect(code.contains(banned), isFalse, reason: '$code に $banned');
        }
      }
    });
  });

  group('FriendCode.normalize / isValidFormat', () {
    test('小文字・前後空白を正規化する', () {
      expect(FriendCode.normalize('  gm-abcde-23456 '), 'GM-ABCDE-23456');
    });

    test('ハイフン抜けでも GM＋10文字なら整形する', () {
      expect(FriendCode.normalize('GMABCDE23456'), 'GM-ABCDE-23456');
      expect(FriendCode.normalize('gm abcde 23456'), 'GM-ABCDE-23456');
    });

    test('整形結果は検証を通る', () {
      expect(
        FriendCode.isValidFormat(FriendCode.normalize('gmabcde23456')),
        isTrue,
      );
    });

    test('旧形式 GM-XXXX（4桁）は無効', () {
      expect(FriendCode.isValidFormat('GM-1029'), isFalse);
      expect(
        FriendCode.isValidFormat(FriendCode.normalize('GM-1029')),
        isFalse,
      );
    });

    test('使用できない文字を含むコードは無効', () {
      expect(FriendCode.isValidFormat('GM-ABCDE-2345O'), isFalse);
      expect(FriendCode.isValidFormat('GM-ABCDE-23451'), isFalse);
      expect(FriendCode.isValidFormat('GM-ABCDE-2345'), isFalse);
      expect(FriendCode.isValidFormat(''), isFalse);
    });
  });

  group('SharedRecord', () {
    final visited = DateTime(2026, 11, 1, 12, 0);
    final record = RestaurantRecord(
      id: 'r1',
      name: 'テスト食堂',
      category: '🍚 定食',
      latitude: 34.6762,
      longitude: 133.9206,
      chargeCount: 3,
      priceRange: '〜1,000円',
      goodPoints: const ['味が最高'],
      imagePath: '/tmp/photo.jpg',
      imageBase64: 'aGVsbG8=',
      lastVisitedAt: visited,
    );

    test('共有JSONに写真と訪問日時が含まれない', () {
      final json = SharedRecord.fromRecord(record).toJson();
      expect(json.containsKey('imageBase64'), isFalse);
      expect(json.containsKey('imagePath'), isFalse);
      expect(json.containsKey('lastVisitedAt'), isFalse);
      expect(json.keys.toSet(), {
        'id',
        'name',
        'category',
        'latitude',
        'longitude',
        'chargeCount',
        'priceRange',
        'goodPoints',
        'comment',
      });
    });

    test('共有JSONの往復で共有項目が保持される', () {
      final restored =
          SharedRecord.fromJson(SharedRecord.fromRecord(record).toJson());
      expect(restored.id, 'r1');
      expect(restored.name, 'テスト食堂');
      expect(restored.latitude, 34.6762);
      expect(restored.longitude, 133.9206);
      expect(restored.chargeCount, 3);
      expect(restored.goodPoints, ['味が最高']);
    });

    test('受信側変換では写真なし・訪問日時は受信時刻になる', () {
      final receivedAt = DateTime(2026, 11, 6, 22, 0);
      final restored = SharedRecord.fromRecord(record)
          .toRestaurantRecord(receivedAt: receivedAt);
      expect(restored.imageBase64, isNull);
      expect(restored.imagePath, isNull);
      expect(restored.lastVisitedAt, receivedAt);
    });
  });

  group('FriendProfile isSample', () {
    test('JSON往復で isSample が保持され、旧データでは false になる', () {
      final sample = FriendProfile(
        friendCode: 'GM-1029',
        displayName: 'メンマ先輩',
        avatarEmoji: '🍜',
        title: '👑 伝説のグルメ覇王',
        colorValue: 0xFF7B1FA2,
        records: const [],
        syncedAt: DateTime(2026, 11, 6),
        isSample: true,
      );
      expect(FriendProfile.fromJson(sample.toJson()).isSample, isTrue);

      final legacyJson = sample.toJson()..remove('isSample');
      expect(FriendProfile.fromJson(legacyJson).isSample, isFalse);
    });
  });
}
