import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a simple placeholder widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Agora test harness')),
        ),
      ),
    );

    expect(find.text('Agora test harness'), findsOneWidget);
    expect(find.byType(Center), findsOneWidget);
  });
}
