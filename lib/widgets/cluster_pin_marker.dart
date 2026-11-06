import 'package:flutter/material.dart';

/// F2：ズームアウト時に近いピンをまとめる「クラスタピン」。
/// タップするとその範囲へズームインする。
class ClusterPinMarker extends StatelessWidget {
  final int shopCount;
  final VoidCallback onTap;

  const ClusterPinMarker({
    super.key,
    required this.shopCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF37474F),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.layers, color: Colors.white, size: 24),
          ),
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '$shopCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
