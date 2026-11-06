import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/restaurant_record.dart';
import '../services/share_service.dart';

/// マップ上の店舗ピンをタップした際に表示する店舗詳細・SNSシェア・クイックチャージシート（ステップ⑤＆⑥）
class RestaurantDetailSheet extends StatefulWidget {
  final RestaurantRecord record;
  final VoidCallback onQuickCharge;
  final VoidCallback onDelete;

  /// この店をフレンドへ共有するかの切り替え（店ごとの共有設定）。
  final void Function(bool value)? onToggleShared;

  const RestaurantDetailSheet({
    super.key,
    required this.record,
    required this.onQuickCharge,
    required this.onDelete,
    this.onToggleShared,
  });

  @override
  State<RestaurantDetailSheet> createState() => _RestaurantDetailSheetState();
}

class _RestaurantDetailSheetState extends State<RestaurantDetailSheet> {
  final GlobalKey _shopCardBoundaryKey = GlobalKey();
  bool _isSharing = false;
  late bool _isShared = widget.record.isShared;

  Future<void> _handlePostToX() async {
    final text = ShareService.buildRestaurantShareText(widget.record);
    final ok = await ShareService.postToX(text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xの起動に失敗しました。隣のシェアボタンをお試しください。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleShareShopCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final text = ShareService.buildRestaurantShareText(widget.record);
      await ShareService.captureAndShareCard(
        boundaryKey: _shopCardBoundaryKey,
        shareText: text,
        fileName: 'shop_${widget.record.id}.png',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final count = record.chargeCount;
    final isGold = count >= 3;
    final isSilver = count == 2;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ハンドル
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
            const SizedBox(height: 10),

            // 上部アクションバー（削除＆閉じる）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '店舗詳細 ＆ シェア',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onDelete,
                      tooltip: 'この記録を削除',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.grey,
                        size: 22,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 22),
                    ),
                  ],
                ),
              ],
            ),

            // ====== 画像キャプチャ対象：店舗紹介カード ======
            RepaintBoundary(
              key: _shopCardBoundaryKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isGold
                        ? const Color(0xFFFFB300)
                        : isSilver
                            ? const Color(0xFF90A4AE)
                            : const Color(0xFFCD7F32),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ランクバッジ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isGold
                                  ? const [Color(0xFFFFD700), Color(0xFFFF6F00)]
                                  : isSilver
                                      ? const [
                                          Color(0xFFB0BEC5),
                                          Color(0xFF546E7A)
                                        ]
                                      : const [
                                          Color(0xFFCD7F32),
                                          Color(0xFF8B4513)
                                        ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isGold
                                    ? Icons.local_fire_department
                                    : isSilver
                                        ? Icons.stars_rounded
                                        : Icons.restaurant,
                                color: Colors.white,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${record.rankTitle} • 来店 $count回',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          '#グルメマップ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

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
                      '${record.category}  •  💰 価格帯: ${record.priceRange}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 料理写真表示（記録されている場合）
                    if (record.imageBase64 != null &&
                        record.imageBase64!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          base64Decode(record.imageBase64!),
                          width: double.infinity,
                          height: 170,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 一言コメント
                    if (record.comment.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: Text(
                          '💬 ${record.comment}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // 良かった点タグ一覧
                    if (record.goodPoints.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: record.goodPoints.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              '👍 $tag',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange.shade800,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 店ごとのフレンド共有ON/OFF
            if (widget.onToggleShared != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  '👥 フレンドにこの店を共有する',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _isShared ? 'フレンドの地図にも表示されます' : 'フレンドには表示されません（自分だけの記録）',
                  style: const TextStyle(fontSize: 11),
                ),
                value: _isShared,
                onChanged: (value) {
                  setState(() => _isShared = value);
                  widget.onToggleShared!(value);
                },
              ),

            // ====== ステップ⑥：X（旧Twitter）投稿 ＆ 他アプリへのカード画像シェアボタン ======
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _handlePostToX,
                      icon: const Text(
                        '𝕏',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      label: const Text(
                        'Xに店舗をポスト',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5722),
                        side: const BorderSide(
                          color: Color(0xFFFF5722),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSharing ? null : _handleShareShopCard,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share, size: 18),
                      label: const Text(
                        'カード画像をシェア',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ワンタップ追加チャージボタン
            SizedBox(
              width: double.infinity,
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
                  widget.onQuickCharge();
                },
                icon: const Icon(Icons.bolt),
                label: Text(
                  count == 1
                      ? '⚡ リピートチャージ！（2回目・銀ピンへ進化）'
                      : count == 2
                          ? '🔥 リピートチャージ！（3回目・金＋炎ピンへ進化）'
                          : '🔥 さらにリピートチャージ！（${count + 1}回目）',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
