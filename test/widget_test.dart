import 'package:flutter_test/flutter_test.dart';
import 'package:gourmet_map/main.dart';

void main() {
  testWidgets('GourmetMapApp builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GourmetMapApp());
    expect(find.byType(GourmetMapApp), findsOneWidget);
  });
}
