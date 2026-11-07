import 'package:flutter/material.dart';
import '../models/friend_profile.dart';
import '../services/share_service.dart';

/// フレンドの「グルメ名刺」を読み取り専用で表示するシート。
/// テーマはフレンドが設定したもの（同期で受け取る）を使う。
class FriendCardSheet extends StatelessWidget {
  final FriendProfile friend;

  const FriendCardSheet({super.key, required this.friend});

  // GourmetCardSheet と同じテーマパレット
  static const List<List<Color>> _themeGradients = [
    [Color(0xFF1E1E2C), Color(0xFF2D1B1E), Color(0xFF3E1F14)],
    [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    [Color(0xFF4A0E0E), Color(0xFF7B1F1F), Color(0xFF3E1E04)],
    [Color(0xFF1B2A1B), Color(0xFF2E4A2A), Color(0xFF556B2F)],
    [Color(0xFF2D1B4E), Color(0xFF7B2D5B), Color(0xFFE65100)],
    [Color(0xFF0A1628), Color(0xFF10243E), Color(0xFF1B3A5C)],
  ];
  static const List<Color> _themeAccents = [
    Color(0xFFFFD54F),
    Color(0xFF00E5FF),
    Color(0xFFFFB74D),
    Color(0xFFC5E1A5),
    Color(0xFFFFAB91),
    Color(0xFF82B1FF),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = (friend.cardThemeIndex >= 0 &&
            friend.cardThemeIndex < _themeGradients.length)
        ? friend.cardThemeIndex
        : 0;
    final gradient = _themeGradients[idx];
    final accent = _themeAccents[idx];
    final title = friend.title.isNotEmpty
        ? friend.title
        : ShareService.calculateGourmetTitle(friend.records);
    final top3 = [...friend.records]
      ..sort((a, b) => b.chargeCount.compareTo(a.chargeCount));

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
          const SizedBox(height: 14),
          Text(
            '${friend.displayName}さんの名刺',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),

          // 名刺カード本体
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accent, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: friend.themeColor,
                      child: Text(
                        friend.avatarEmoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            title,
                            style: TextStyle(
                              color: accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('登録店舗', '${friend.records.length}件'),
                    _stat('総チャージ', '${friend.totalCharges}回'),
                    _stat(
                      '常連店（10回〜）',
                      '${friend.records.where((r) => r.chargeCount >= 10).length}件',
                    ),
                  ],
                ),
                if (top3.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 10),
                  for (final r in top3.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${r.category.split(' ').first} ${r.name}（${r.chargeCount}回）',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'フレンドコード: ${friend.friendCode}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
        ),
      ],
    );
  }
}
