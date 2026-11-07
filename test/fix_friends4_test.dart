import 'package:flutter_test/flutter_test.dart';
import 'package:gourmet_map/models/friend_profile.dart';
import 'package:gourmet_map/utils/pin_grouping.dart';

void main() {
  group('fanOutOffsets（合体ピンの扇状配置）', () {
    test('1件は中心、2件は左右に分かれる', () {
      expect(fanOutOffsets(1).length, 1);
      expect(fanOutOffsets(1).first.dx, 0);
      final two = fanOutOffsets(2);
      expect(two.length, 2);
      // 左右対称で、上下は同じ高さ
      expect(two[0].dx, -two[1].dx);
      expect(two[0].dy, two[1].dy);
      expect(two[0].dx.abs(), greaterThan(10));
    });

    test('3件以上は全て異なる位置になる', () {
      final four = fanOutOffsets(4);
      expect(four.length, 4);
      final keys = four.map((o) => '${o.dx},${o.dy}').toSet();
      expect(keys.length, 4);
    });
  });

  group('FriendProfile の名刺テーマ', () {
    test('JSON往復で保持され、旧形式では0になる', () {
      final friend = FriendProfile(
        friendCode: 'GM-AAAAA-AAAAA',
        displayName: '友達',
        avatarEmoji: '🍜',
        title: '称号',
        colorValue: 0xFF7B1FA2,
        records: const [],
        syncedAt: DateTime(2026, 11, 7),
        cardThemeIndex: 4,
      );
      final restored = FriendProfile.fromJson(friend.toJson());
      expect(restored.cardThemeIndex, 4);

      final legacy = friend.toJson()..remove('cardThemeIndex');
      expect(FriendProfile.fromJson(legacy).cardThemeIndex, 0);
    });
  });
}
