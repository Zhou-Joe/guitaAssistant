import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_assistant/app.dart';

void main() {
  testWidgets('app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const GuitarApp());
    await tester.pumpAndSettle();

    expect(find.text('Guitar Assistant'), findsOneWidget);
  });
}
