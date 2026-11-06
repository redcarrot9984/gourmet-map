import 'package:flutter/material.dart';
import '../models/restaurant_record.dart';

/// ステップ⑤＆⑧：来店チャージ数に応じて豪華に進化＆アニメーションする店舗ピンウィジェット
/// - 1回 ＝ 銅色（ブロンズ・通常サイズ）
/// - 2回 ＝ 銀色（シルバー・少し大きいサイズ＋スター）
/// - 3〜4回 ＝ 金色＋炎アイコン（ゴールド・特大サイズ＋炎オーラ）
/// - 5回以上 ＝ 殿堂入りレジェンド（ロイヤルゴールド＋王冠＆炎の最高峰演出）
class RestaurantPinMarker extends StatefulWidget {
  final RestaurantRecord record;
  final VoidCallback onTap;

  const RestaurantPinMarker({
    super.key,
    required this.record,
    required this.onTap,
  });

  /// チャージ回数に応じたマーカー全体の幅
  static double markerWidthForCount(int count) {
    if (count >= 5) return 124; // 殿堂入り特大サイズ
    if (count >= 3) return 116; // 特大サイズ
    if (count == 2) return 100; // 少し大きいサイズ
    return 88; // 通常サイズ
  }

  /// チャージ回数に応じたマーカー全体の高さ
  static double markerHeightForCount(int count) {
    if (count >= 5) return 112; // 殿堂入り特大サイズ
    if (count >= 3) return 104; // 特大サイズ
    if (count == 2) return 88; // 少し大きいサイズ
    return 76; // 通常サイズ
  }

  @override
  State<RestaurantPinMarker> createState() => _RestaurantPinMarkerState();
}

class _RestaurantPinMarkerState extends State<RestaurantPinMarker>
    with SingleTickerProviderStateMixin {
  AnimationController? _flameController;

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant RestaurantPinMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.chargeCount != widget.record.chargeCount) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.record.chargeCount >= 3) {
      _flameController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat(reverse: true);
    } else {
      _flameController?.dispose();
      _flameController = null;
    }
  }

  @override
  void dispose() {
    _flameController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final count = record.chargeCount;
    final isLegend = count >= 5;
    final isGold = count >= 3;
    final isSilver = count == 2;

    // ピン円のサイズ（1回: 38, 2回: 48, 3〜4回: 60, 5回以上: 64）
    final double pinCircleSize =
        isLegend ? 64 : (isGold ? 60 : (isSilver ? 48 : 38));

    final List<Color> gradientColors = isLegend
        ? const [
            Color(0xFFFFFDE7),
            Color(0xFFFFD700),
            Color(0xFFFF3D00),
            Color(0xFFAA00FF),
          ]
        : isGold
            ? const [
                Color(0xFFFFF59D),
                Color(0xFFFFD700),
                Color(0xFFFF8F00),
              ]
            : isSilver
                ? const [
                    Color(0xFFFFFFFF),
                    Color(0xFFCFD8DC),
                    Color(0xFF607D8B),
                  ]
                : const [
                    Color(0xFFE6A15C),
                    Color(0xFFCD7F32),
                    Color(0xFF8B4513),
                  ];

    final Color borderColor = isLegend
        ? const Color(0xFFFFEA00)
        : isGold
            ? const Color(0xFFFF3D00)
            : isSilver
                ? Colors.white
                : const Color(0xFFFFE0B2);

    final Color badgeBgColor = isLegend
        ? const Color(0xFF6A1B9A)
        : isGold
            ? const Color(0xFFD50000)
            : isSilver
                ? const Color(0xFF37474F)
                : const Color(0xFF5D4037);

    Widget pinBody = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 3回以上（金ピン／殿堂入り）の背面オーラ発光エフェクト
            if (isGold)
              Container(
                width: pinCircleSize + 16,
                height: pinCircleSize + 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isLegend
                              ? const Color(0xFFD500F9)
                              : const Color(0xFFFF6D00))
                          .withValues(alpha: 0.58),
                      const Color(0xFFFFD600).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

            // メインの丸ピン
            Container(
              width: pinCircleSize,
              height: pinCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                border: Border.all(
                  color: borderColor,
                  width: isGold ? 3.5 : (isSilver ? 3.0 : 2.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isGold
                        ? const Color(0xFFFF6D00).withValues(alpha: 0.65)
                        : Colors.black.withValues(alpha: 0.35),
                    blurRadius: isGold ? 12 : (isSilver ? 8 : 5),
                    spreadRadius: isGold ? 2 : 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: isGold
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: isLegend
                                ? const Color(0xFFFFEA00)
                                : const Color(0xFFD50000),
                            size: isLegend ? 38 : 36,
                          ),
                          Positioned(
                            bottom: 4,
                            child: Icon(
                              isLegend ? Icons.workspace_premium : Icons.restaurant,
                              color: Colors.white.withValues(alpha: 0.95),
                              size: 16,
                            ),
                          ),
                        ],
                      )
                    : Icon(
                        isSilver ? Icons.stars_rounded : Icons.restaurant,
                        color: isSilver
                            ? const Color(0xFF263238)
                            : Colors.white,
                        size: isSilver ? 26 : 19,
                      ),
              ),
            ),

            // 3回以上の場合は上部に王冠・炎クレストを表示
            if (isGold)
              Positioned(
                top: -11,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isLegend
                        ? const Color(0xFF4A148C)
                        : const Color(0xFFFF3D00),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.yellowAccent, width: 1.3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLegend
                            ? Icons.emoji_events
                            : Icons.local_fire_department,
                        color: Colors.yellowAccent,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isLegend ? '殿堂' : 'MAX',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 右下のチャージ回数バッジ
            Positioned(
              right: -6,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isGold ? Colors.yellowAccent : Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  isLegend
                      ? '👑×$count'
                      : isGold
                          ? '🔥×$count'
                          : isSilver
                              ? '⚡×$count'
                              : '×$count',
                  style: TextStyle(
                    color: isGold ? Colors.yellowAccent : Colors.white,
                    fontSize: isGold ? 11 : 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),

        // 店名ミニラベル
        Container(
          constraints: const BoxConstraints(maxWidth: 114),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isGold
                ? const Color(0xFF212121).withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isLegend
                  ? const Color(0xFFE040FB)
                  : isGold
                      ? const Color(0xFFFFD700)
                      : isSilver
                          ? const Color(0xFF90A4AE)
                          : const Color(0xFFCD7F32),
              width: 1.3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            record.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isGold ? 10.5 : 9.5,
              fontWeight: FontWeight.bold,
              color: isGold ? const Color(0xFFFFD700) : Colors.black87,
            ),
          ),
        ),
      ],
    );

    if (_flameController != null) {
      pinBody = AnimatedBuilder(
        animation: _flameController!,
        builder: (context, child) {
          final scale = 1.0 + (_flameController!.value * 0.06);
          return Transform.scale(scale: scale, child: child);
        },
        child: pinBody,
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: pinBody,
    );
  }
}
