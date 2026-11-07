import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmet_map/widgets/gourmet_card_sheet.dart';

void main() {
  testWidgets('名刺シート：記録ゼロの初期状態でカードが描画される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GourmetCardSheet(
            avatarEmoji: '🔥',
            onAvatarChanged: (_) {},
            initialUserName: 'グルメ探検家',
            customTitle: null,
            cardThemeIndex: 0,
            isProMember: false,
            records: const [],
            friends: const [],
            onUserNameChanged: (_) {},
            onCustomTitleChanged: (_) {},
            onCardThemeChanged: (_) {},
            onOpenPaywall: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 例外が出ていれば ErrorWidget（灰色）になっているはず
    expect(tester.takeException(), isNull);
    expect(find.text('まだ店舗が登録されていません。街のグルメを記録しよう！'), findsOneWidget);
    expect(find.text('グルメ探検家'), findsOneWidget);
  });
}
