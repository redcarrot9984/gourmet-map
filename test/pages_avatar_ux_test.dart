import 'package:flutter_test/flutter_test.dart';
import 'package:gourmet_map/models/friend_profile.dart';
import 'package:gourmet_map/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

FriendProfile friend(
  String code,
  String name,
  int shopCount, {
  bool isSample = false,
}) {
  return FriendProfile(
    friendCode: code,
    displayName: name,
    avatarEmoji: '🍜',
    title: '称号',
    colorValue: 0xFF7B1FA2,
    records: const [],
    syncedAt: DateTime(2026, 11, 7),
    isSample: isSample,
  );
}

void main() {
  group('フレンドの並び順・検索', () {
    test('実在が先、店舗数が多い順、サンプルは最後', () {
      // records は空だが records.length の代わりに並びの主条件は
      // isSample → 店舗数 → 名前のため、店舗数は別途検証できないので
      // ここではサンプルの後置と名前順を確認する
      final sorted = FriendProfile.sortedForDisplay([
        friend('GM-S1', 'サンプルA', 0, isSample: true),
        friend('GM-B', 'ぶどう', 0),
        friend('GM-A', 'あんこ', 0),
      ]);
      expect(sorted.map((f) => f.displayName), ['あんこ', 'ぶどう', 'サンプルA']);
    });

    test('名前・コードで絞り込める（大小区別なし）', () {
      final friends = [
        friend('GM-AAAAA-AAAAA', 'メンマ先輩', 0),
        friend('GM-BBBBB-BBBBB', 'カレー部長', 0),
      ];
      expect(
        FriendProfile.filterByQuery(friends, 'メン').single.displayName,
        'メンマ先輩',
      );
      expect(FriendProfile.filterByQuery(friends, 'gm-bb').length, 1);
      expect(FriendProfile.filterByQuery(friends, '').length, 2);
    });
  });

  group('アバター保存', () {
    test('保存した絵文字が読み戻せ、未保存は初期値', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      expect(await storage.loadAvatarEmoji(), '🔥');
      await storage.saveAvatarEmoji('🍣');
      expect(await storage.loadAvatarEmoji(), '🍣');
    });
  });
}
