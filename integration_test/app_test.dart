import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_assistant/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Guitar Assistant App', () {
    testWidgets('app launches successfully', (tester) async {
      await tester.pumpWidget(const GuitarApp());
      await tester.pumpAndSettle();

      expect(find.text('Guitar Assistant'), findsOneWidget);
    });

    testWidgets('bottom navigation is visible', (tester) async {
      await tester.pumpWidget(const GuitarApp());
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('tuner screen can be accessed', (tester) async {
      await tester.pumpWidget(const GuitarApp());
      await tester.pumpAndSettle();

      // Tap on tuner in bottom nav
      final tunerTab = find.text('Tuner');
      await tester.tap(tunerTab);
      await tester.pumpAndSettle();

      expect(find.text('Tuner'), findsOneWidget);
    });

    testWidgets('metronome screen can be accessed', (tester) async {
      await tester.pumpWidget(const GuitarApp());
      await tester.pumpAndSettle();

      final metronomeTab = find.text('Metronome');
      await tester.tap(metronomeTab);
      await tester.pumpAndSettle();

      expect(find.text('Metronome'), findsOneWidget);
    });
  });
}
