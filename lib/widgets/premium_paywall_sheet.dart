import 'package:flutter/material.dart';

/// ステップ⑨：AdMobスマートバナー（PROプラン未加入時に表示、ワンタップで非表示導線付き）
class AdMobSmartBanner extends StatelessWidget {
  final bool isProMember;
  final VoidCallback onTapRemoveAds;

  /// Google AdMob 公式テスト用バナー広告ユニットID
  static const String androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String iosTestBannerId =
      'ca-app-pub-3940256099942544/2934735716';

  const AdMobSmartBanner({
    super.key,
    required this.isProMember,
    required this.onTapRemoveAds,
  });

  @override
  Widget build(BuildContext context) {
    if (isProMember) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF263238).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'AD',
              style: TextStyle(
                color: Colors.black,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'グルメパスPROで広告非表示＆限定名刺テーマを解放！',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: const Color(0xFFECEFF1),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: onTapRemoveAds,
            child: const Text(
              '広告を消す ＞',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ステップ⑨：グルメパス PRO（課金導線・広告非表示・限定特典）ボトムシート
class PremiumPaywallSheet extends StatelessWidget {
  final bool isProMember;
  final ValueChanged<bool> onTogglePro;

  const PremiumPaywallSheet({
    super.key,
    required this.isProMember,
    required this.onTogglePro,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF263238),
            Color(0xFF37474F),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // 王冠アイコン
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFD700),
            ),
            child: const Icon(
              Icons.workspace_premium,
              size: 36,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'グルメマップ PRO パス',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'あなたのグルメ開拓と名刺を最高峰へアップグレード',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 20),

          // 特典リスト
          _buildFeatureItem(
            icon: Icons.block,
            title: 'すべてのバナー広告を完全非表示',
            subtitle: '地図画面がさらに広く、ストレスフリーで操作可能に',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: Icons.palette_outlined,
            title: '限定グルメ名刺テーマ「🌸 和風朱雅」解放',
            subtitle: 'SNSシェアで圧倒的に目を引く特別デザイン',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: Icons.verified_rounded,
            title: '名刺とヘッダーに「👑 PRO」称号刻印',
            subtitle: 'フレンド共有時にも輝くゴールドPROエンブレム',
          ),

          const SizedBox(height: 24),

          // 価格＆即時体験ボタン
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isProMember
                    ? Colors.grey.shade700
                    : const Color(0xFFFFD700),
                foregroundColor: isProMember ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                final nextState = !isProMember;
                Navigator.of(context).pop();
                onTogglePro(nextState);
              },
              icon: Icon(
                isProMember ? Icons.restore : Icons.bolt,
                size: 22,
              ),
              label: Text(
                isProMember
                    ? '現在PRO有効中（タップで無料プラン表示に戻す）'
                    : '👑 ¥300/月（今すぐ無料でPROモードを体験ON！）',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'あとにする',
              style: TextStyle(color: Colors.white54, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFCFD8DC), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
