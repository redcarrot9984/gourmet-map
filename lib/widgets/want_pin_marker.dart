import 'package:flutter/material.dart';

import '../models/want_to_visit.dart';

/// N1：「行きたい店」のピン。登録済みピン（丸）と区別できるよう、
/// しおり型のティール色マーカーで表示する。
class WantPinMarker extends StatelessWidget {
  final WantToVisit want;
  final VoidCallback onTap;

  const WantPinMarker({super.key, required this.want, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B),
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
              '🔖 ${want.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(
            Icons.bookmark,
            color: Color(0xFF00897B),
            size: 34,
            shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
          ),
        ],
      ),
    );
  }
}
