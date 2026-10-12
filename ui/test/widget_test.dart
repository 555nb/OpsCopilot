import 'package:flutter_test/flutter_test.dart';
import 'package:opscopilot_ui/main.dart';

void main() {
  testWidgets('OpsCopilot App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OpsCopilotApp());
    expect(find.text('OpsCopilot'), findsOneWidget);
  });
}
