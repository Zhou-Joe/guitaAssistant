import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_assistant/app.dart';

void main() {
  testWidgets('app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const GuitarApp());
    await tester.pump(); // Give one frame to render

    // Verify the app loaded by checking for Scaffold
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
