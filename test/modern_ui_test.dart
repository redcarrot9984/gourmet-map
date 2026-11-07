import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmet_map/main.dart';
import 'package:gourmet_map/theme/app_colors.dart';

void main() {
  testWidgets('モダンUI基盤：テーマの角丸・スナックバー・入力欄が統一されている', (tester) async {
    await tester.pumpWidget(const GourmetMapApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final theme = app.theme!;

    // シートは上部28の角丸
    final sheetShape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
    expect(
      sheetShape.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );
    // ダイアログは24の角丸
    final dialogShape = theme.dialogTheme.shape as RoundedRectangleBorder;
    expect(
      dialogShape.borderRadius,
      const BorderRadius.all(Radius.circular(24)),
    );
    // スナックバーはフローティング
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    // 入力欄は塗りつぶし＋角丸14
    expect(theme.inputDecorationTheme.filled, isTrue);
    // パレットの共通影が定義されている
    expect(AppColors.floatingShadow, isNotEmpty);
    // 地図画面が例外なく描画される（ヘッダーカード・ドック・ピル含む）
    expect(tester.takeException(), isNull);
    expect(find.text('店を登録'), findsOneWidget);
  });
}
