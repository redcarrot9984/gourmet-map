import 'package:flutter/material.dart';
import '../models/friend_profile.dart';
import '../models/restaurant_record.dart';
import '../services/share_service.dart';

/// ステップ⑦：マップ上の「フレンドの店舗ピン」をタップした際に表示する詳細＆自分のマップへの取り込みシート
class FriendRestaurantDetailSheet extends StatelessWidget {
  final FriendProfile friend;
  final RestaurantRecord record;
  final VoidCallback onImportToMyMap;

  /// N2：行きたいリストへの追加（サンプルフレンドでは null で非表示）。
  final VoidCallback? onAddToWantList;

  /// フレンドの名刺を表示する。
  final VoidCallback? onViewCard;

  const FriendRestaurantDetailSheet({
    super.key,
    required this.friend,
    required this.record,
    required this.onImportToMyMap,
    this.onAddToWantList,
    this.onViewCard,
  });

  @override
  Widget build(BuildContext context) {
    final count = record.chargeCount;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // フレンド紹介ヘッダーバッジ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: friend.themeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      friend.avatarEmoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${friend.displayName} さんの常連店（来店 $count回）',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 店名＆カテゴリ
          Text(
            record.name,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${record.category}  •  💰 価格帯: ${record.priceRange}  •  ${record.rankTitle}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // フレンドの一言コメント
          if (record.comment.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCE93D8)),
              ),
              child: Text(
                '💬 ${friend.displayName}さん：${record.comment}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // フレンドが選んだ良かった点タグ
          if (record.goodPoints.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: record.goodPoints.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: friend.themeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: friend.themeColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '👍 $tag',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: friend.themeColor,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],

          // アクションボタン：自分もこの店に行ってチャージ登録する！
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onImportToMyMap();
                    },
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text(
                      '自分も行った！（マイマップにチャージ）',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final text = '🍴 フレンド【${friend.displayName}】さんのおすすめ店！\n'
                        '「${record.name}」（${record.category} / チャージ${record.chargeCount}回）\n'
                        '#グルメマップ #友達のグルメマップ';
                    ShareService.postToX(text);
                  },
                  child: const Text(
                    '𝕏',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),

          // フレンドの名刺を見る
          if (onViewCard != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: friend.themeColor,
                  side: BorderSide(color: friend.themeColor, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onViewCard,
                icon: const Icon(Icons.badge_outlined, size: 19),
                label: const Text(
                  'この人の名刺を見る',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ),
          ],

          // N2：フレンドの店を自分の「行きたいリスト」へ追加
          if (onAddToWantList != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF37474F),
                  side: const BorderSide(color: Color(0xFF00897B), width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onAddToWantList!();
                },
                icon: const Icon(Icons.bookmark_add_outlined, size: 19),
                label: const Text(
                  '行きたいリストに追加',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
