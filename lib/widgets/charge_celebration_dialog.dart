import 'package:flutter/material.dart';
import '../models/restaurant_record.dart';
import '../services/share_service.dart';

/// ステップ⑧：店舗登録・チャージ成功時のゲーム風ランクアップ＆EXP獲得演出ダイアログ
class ChargeCelebrationDialog extends StatelessWidget {
  final RestaurantRecord record;
  final bool isRepeat;
  final int gainedExp;
  final int currentLevel;

  const ChargeCelebrationDialog({
    super.key,
    required this.record,
    required this.isRepeat,
    required this.gainedExp,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final count = record.chargeCount;
    final isLegend = count >= 30;
    final isGold = count >= 10;
    final isSilver = count == 2;

    // ランク色は意味があるので残すが、グラデーションはやめて単色にする
    final Color rankColor = isLegend
        ? const Color(0xFF37474F)
        : isGold
            ? const Color(0xFFFF8F00)
            : isSilver
                ? const Color(0xFF78909C)
                : const Color(0xFF8D6E63);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isGold ? const Color(0xFFFFD700) : const Color(0xFFCFD8DC),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アイコンサークル
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rankColor,
                boxShadow: [
                  BoxShadow(
                    color: rankColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isLegend
                    ? Icons.emoji_events
                    : isGold
                        ? Icons.local_fire_department
                        : isSilver
                            ? Icons.stars_rounded
                            : Icons.restaurant,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 12),

            // 演出見出し
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECEFF1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isRepeat
                    ? (count == 100
                        ? '🌈 RAINBOW RANK UP!! 🌈'
                        : count == 50
                            ? '💎 DIAMOND RANK UP!! 💎'
                            : count == 30
                                ? '👑 LEGEND RANK UP!! 👑'
                                : count == 20
                                    ? '🔷 PLATINUM RANK UP!! 🔷'
                                    : count == 10
                                        ? '🔥 GOLD RANK UP!! 🔥'
                                        : count == 2
                                            ? '⚡ SILVER RANK UP!! ⚡'
                                            : '⚡ CHARGE UP!! (+1)')
                    : '🎉 NEW SPOT DISCOVERED!!',
                style: const TextStyle(
                  color: Color(0xFF37474F),
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 店名
            Text(
              record.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '来店チャージ：$count回目  •  ${record.rankTitle}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),

            // 獲得EXPバッジ
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'プレイヤー Lv.$currentLevel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '＋$gainedExp EXP 獲得！',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Xシェア ＆ 閉じるボタン
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final text =
                          ShareService.buildRestaurantShareText(record);
                      ShareService.postToX(text);
                    },
                    icon: const Text(
                      '𝕏',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    label: const Text(
                      'Xにポスト',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'マップを見る',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
