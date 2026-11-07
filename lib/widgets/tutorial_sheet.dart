import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 初回起動時に自動表示される使い方チュートリアル。
/// 上部の「使い方」からいつでも開き直せる。
class TutorialSheet extends StatefulWidget {
  const TutorialSheet({super.key});

  @override
  State<TutorialSheet> createState() => _TutorialSheetState();
}

class _TutorialSheetState extends State<TutorialSheet> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = <({IconData icon, String title, String body})>[
    (
      icon: Icons.map_outlined,
      title: 'お店を記録して、自分の地図を作ろう',
      body: '行ったお店を登録すると、地図にピンが立ちます。\n'
          '通うほどピンが育って、ランクが上がっていきます。',
    ),
    (
      icon: Icons.bolt,
      title: '来店のたびに「チャージ」',
      body: '下の「店を登録」ボタンから、近くの店を選んで写真・価格・タグを付けて登録。\n'
          '同じ店に行くたびにチャージすると、2回で銀、10回で金…とピンがランクアップします。',
    ),
    (
      icon: Icons.people_alt_outlined,
      title: 'フレンドとおすすめを共有',
      body: '右下の人型ボタンから「フレンド管理」を開き、フレンドコードを交換しましょう。\n'
          '友達のおすすめ店が地図に表示され、コードはLINEでも送れます。',
    ),
    (
      icon: Icons.bookmark_border,
      title: '行きたい店と、あなたの名刺',
      body: '気になる店は長押しや検索から「行きたいリスト」へ。実際に行って登録すると自動で卒業します。\n'
          '左下のレベル表示をタップすると、あなたの実績をまとめた「名刺」が見られます。',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),
          Flexible(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final page = _pages[i];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.mist,
                      ),
                      child:
                          Icon(page.icon, size: 34, color: AppColors.primary),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      page.body,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.7,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              return Container(
                width: i == _page ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.primary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'スキップ',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (isLast) {
                      Navigator.of(context).pop();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(
                    isLast ? 'はじめる' : '次へ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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

/// チュートリアルをボトムシートで開く共通ヘルパー。
Future<void> showTutorialSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const TutorialSheet(),
  );
}
