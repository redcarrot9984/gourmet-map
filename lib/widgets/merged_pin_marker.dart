import 'package:flutter/material.dart';

import '../utils/pin_grouping.dart';

/// F1：同じ場所に複数のピンが重なる場合の「合体ピン」。
/// 自分の店とフレンドの店（または複数フレンドの店）が近い場所にあるときに
/// 1つにまとめて表示し、タップで選択シートを開く。
class MergedPinMarker extends StatelessWidget {
  final PinGroup group;
  final VoidCallback onTap;

  const MergedPinMarker({super.key, required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasMine = group.hasMine;
    final friendEmojis = group.entries
        .where((e) => !e.isMine)
        .map((e) => e.friend!.avatarEmoji)
        .toSet()
        .take(2)
        .join();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
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
              '${group.entries.length}件のお店がここにあります',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: hasMine
                        ? const [Color(0xFFFF5722), Color(0xFF7B1FA2)]
                        : const [Color(0xFF7B1FA2), Color(0xFF3949AB)],
                  ),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.restaurant,
                      color: Colors.white,
                      size: 20,
                    ),
                    if (friendEmojis.isNotEmpty)
                      Text(
                        friendEmojis,
                        style: const TextStyle(fontSize: 10, height: 1.0),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                  ),
                  child: Text(
                    '${group.entries.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
