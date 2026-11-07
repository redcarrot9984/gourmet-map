import 'package:flutter/material.dart';
import 'friend_profile.dart';
import 'restaurant_record.dart';

/// ステップ⑧：称号（実績バッジ）モデル
class AchievementBadge {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool isUnlocked;
  final Color color;

  const AchievementBadge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.isUnlocked,
    required this.color,
  });
}

/// ステップ⑧：グルメレベル・経験値(EXP)・称号コレクション計算ユーティリティ
class GamificationEngine {
  /// 店舗リストとフレンドリストから総獲得EXPを計算
  /// - 1店舗開拓ごとに +100 EXP
  /// - チャージ1回ごとに +120 EXP
  /// - 銀ピン(2回以上)ボーナス +100 EXP
  /// - 金ピン(3回以上)ボーナス +250 EXP
  /// - 写真付き記録ボーナス +80 EXP
  /// - フレンド1人追加ごとに +150 EXP
  static int calculateTotalExp({
    required List<RestaurantRecord> records,
    required List<FriendProfile> friends,
  }) {
    int exp = 0;
    for (final r in records) {
      exp += 100; // 開拓基本EXP
      exp += r.chargeCount * 120; // チャージEXP
      if (r.chargeCount >= 2) exp += 100; // 銀ピンボーナス
      if (r.chargeCount >= 3) exp += 250; // 金ピンボーナス
      if (r.imageBase64 != null && r.imageBase64!.isNotEmpty) {
        exp += 80; // 写真ボーナス
      }
    }
    exp += friends.length * 150;
    return exp;
  }

  /// 総EXPから現在レベルと次レベルまでの進捗率(0.0〜1.0)を算出
  static ({int level, int currentLevelExp, int nextLevelExp, double progress})
      calculateLevelInfo({
    required List<RestaurantRecord> records,
    required List<FriendProfile> friends,
  }) {
    final totalExp = calculateTotalExp(records: records, friends: friends);
    // 1レベルあたり 400 EXP でテンポよくレベルアップ
    const int expPerLevel = 400;
    final int level = 1 + (totalExp ~/ expPerLevel);
    final int currentLevelExp = totalExp % expPerLevel;
    final double progress = (currentLevelExp / expPerLevel).clamp(0.0, 1.0);

    return (
      level: level,
      currentLevelExp: currentLevelExp,
      nextLevelExp: expPerLevel,
      progress: progress,
    );
  }

  /// 全12種類の称号（実績バッジ）の解放状況を判定して返す
  static List<AchievementBadge> evaluateBadges({
    required List<RestaurantRecord> records,
    required List<FriendProfile> friends,
  }) {
    final totalCharges =
        records.fold<int>(0, (sum, item) => sum + item.chargeCount);
    final silverOrMore = records.where((r) => r.chargeCount >= 2).length;
    final goldCount = records.where((r) => r.chargeCount >= 3).length;
    final legendCount = records.where((r) => r.chargeCount >= 5).length;
    final photoCount = records
        .where((r) => r.imageBase64 != null && r.imageBase64!.isNotEmpty)
        .length;

    final hasRamen = records.any(
      (r) =>
          r.name.contains('ラーメン') ||
          r.name.contains('麺') ||
          r.category.contains('ラーメン') ||
          r.category.contains('麺'),
    );
    final hasCafe = records.any(
      (r) =>
          r.name.contains('カフェ') ||
          r.name.contains('珈琲') ||
          r.category.contains('カフェ') ||
          r.category.contains('喫茶'),
    );
    final hasCurry = records.any(
      (r) =>
          r.name.contains('カレー') ||
          r.name.contains('スパイス') ||
          r.category.contains('カレー'),
    );
    final cospaCount =
        records.where((r) => r.goodPoints.contains('神コスパ')).length;

    return [
      AchievementBadge(
        id: 'first_step',
        emoji: '🌱',
        title: '期待のグルメ開拓者',
        description: '最初の1店舗をマップに記録する',
        isUnlocked: records.isNotEmpty,
        color: const Color(0xFF43A047),
      ),
      AchievementBadge(
        id: 'silver_charger',
        emoji: '⚡',
        title: '銀の常連チャージャー',
        description: '同じお店に2回訪問して銀ピンに進化させる',
        isUnlocked: silverOrMore >= 1,
        color: const Color(0xFF546E7A),
      ),
      AchievementBadge(
        id: 'gold_regular',
        emoji: '🔥',
        title: '炎の常連マスター',
        description: '同じお店に3回以上訪問して金＋炎ピンを獲得する',
        isUnlocked: goldCount >= 1,
        color: const Color(0xFFFF6F00),
      ),
      AchievementBadge(
        id: 'ramen_mania',
        emoji: '🍜',
        title: '至高の麺類マニア',
        description: 'ラーメン・麺類のお店を記録する',
        isUnlocked: hasRamen,
        color: const Color(0xFFD84315),
      ),
      AchievementBadge(
        id: 'cafe_noble',
        emoji: '☕',
        title: '優雅なるカフェ貴族',
        description: 'カフェ・喫茶店を記録する',
        isUnlocked: hasCafe,
        color: const Color(0xFF6D4C41),
      ),
      AchievementBadge(
        id: 'spice_seeker',
        emoji: '🍛',
        title: '灼熱のスパイス探求者',
        description: 'カレー・スパイス料理店を記録する',
        isUnlocked: hasCurry,
        color: const Color(0xFFF57F17),
      ),
      AchievementBadge(
        id: 'cospa_hunter',
        emoji: '💰',
        title: '神コスパ鑑定士',
        description: '「神コスパ」タグを付けたお店を2店舗以上記録',
        isUnlocked: cospaCount >= 2,
        color: const Color(0xFF00897B),
      ),
      AchievementBadge(
        id: 'gourmet_photographer',
        emoji: '📸',
        title: '敏腕グルメカメラマン',
        description: '料理の写真付きでお店を記録する',
        isUnlocked: photoCount >= 1,
        color: const Color(0xFF1E88E5),
      ),
      AchievementBadge(
        id: 'friend_connector',
        emoji: '👥',
        title: 'グルメ外交官',
        description: 'フレンドを1人以上追加してマップを共有する',
        isUnlocked: friends.isNotEmpty,
        color: const Color(0xFF8E24AA),
      ),
      AchievementBadge(
        id: 'town_pioneer',
        emoji: '🗺️',
        title: '街のグルメ開拓王',
        description: '5店舗以上のお店をマップに記録する',
        isUnlocked: records.length >= 5,
        color: const Color(0xFF3949AB),
      ),
      AchievementBadge(
        id: 'charge_addict',
        emoji: '⚡',
        title: '爆速チャージ中毒',
        description: '総チャージ回数が10回を突破する',
        isUnlocked: totalCharges >= 10,
        color: const Color(0xFFC2185B),
      ),
      AchievementBadge(
        id: 'legend_emperor',
        emoji: '👑',
        title: '伝説のグルメ覇王',
        description: '金ピン3店舗達成 または 1店舗に5回以上チャージ',
        isUnlocked: goldCount >= 3 || legendCount >= 1 || totalCharges >= 15,
        color: const Color(0xFFFFB300),
      ),
    ];
  }
}
