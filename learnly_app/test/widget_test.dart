import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learnly_app/main.dart';

void main() {
  testWidgets('Learnly App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LearnlyApp(),
      ),
    );

    expect(find.text('Learnly AI'), findsOneWidget);
  });
}
