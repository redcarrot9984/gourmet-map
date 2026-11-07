import 'package:flutter/material.dart';
import '../models/friend_profile.dart';
import '../models/restaurant_record.dart';

/// ステップ⑦：マップ上に表示する「フレンドの店舗ピン」ウィジェット
class FriendPinMarker extends StatelessWidget {
  final FriendProfile friend;
  final RestaurantRecord record;
  final VoidCallback onTap;

  const FriendPinMarker({
    super.key,
    required this.friend,
    required this.record,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = record.chargeCount;
    final isGold = count >= 10;
    final isSilver = count >= 2;
    final double circleSize =
        count >= 30 ? 54 : (isGold ? 50 : (isSilver ? 44 : 36));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. フレンド名リボン（誰のおすすめピンかひと目でわかるバッジ）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: friend.themeColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '${friend.avatarEmoji}${friend.displayName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),

          // 2. ピン円本体（チャージ回数に応じて銅・銀・金＋炎）
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isGold
                        ? const [Color(0xFFFFF176), Color(0xFFFF8F00)]
                        : isSilver
                            ? const [Color(0xFFECEFF1), Color(0xFF78909C)]
                            : const [Color(0xFFD7CCC8), Color(0xFF8D6E63)],
                  ),
                  border: Border.all(
                    color: friend.themeColor,
                    width: 3.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: friend.themeColor.withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  // 誰のおすすめか分かるよう、中央はフレンドのアバター絵文字
                  child: Text(
                    friend.avatarEmoji,
                    style: TextStyle(fontSize: circleSize * 0.52),
                  ),
                ),
              ),

              // カテゴリバッジ（左下）
              Positioned(
                left: -6,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: friend.themeColor, width: 1.2),
                  ),
                  child: Text(
                    record.category.split(' ').first,
                    style: const TextStyle(fontSize: 9),
                  ),
                ),
              ),

              // チャージ回数バッジ
              Positioned(
                right: -6,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: friend.themeColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    isGold ? '🔥×$count' : '×$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // 3. 店名ラベル
          Container(
            constraints: const BoxConstraints(maxWidth: 108),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: friend.themeColor, width: 1.2),
            ),
            child: Text(
              record.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.0,
                fontWeight: FontWeight.bold,
                color: friend.themeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
