import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('Smart Sanitation app smoke and foundation render test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartSanitationApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify app brand text is rendered
    expect(find.text('Smart Public Sanitation'), findsOneWidget);
    expect(find.text('Citizen'), findsWidgets);
    expect(find.text('Worker'), findsWidgets);
    expect(find.text('Admin'), findsWidgets);
  });
}
