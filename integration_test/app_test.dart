// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nspff/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Application Integration Tests', () {
    testWidgets('Full User Workflow: Launch -> Navigate -> Configure -> Key Status Check', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify home screen branding
      expect(find.text('NSPFF'), findsOneWidget);
      expect(find.text('FAST FORWARD'), findsOneWidget);

      // Verify Keys Status Pill
      expect(find.text('KEYS NEEDED'), findsOneWidget);

      // Navigate to RetroArch Screen
      await tester.tap(find.text('RetroArch'));
      await tester.pumpAndSettle();
      expect(find.text('RetroArch ROM Forwarder'), findsOneWidget);

      // Navigate to Batch Screen
      await tester.tap(find.text('Batch ROMs'));
      await tester.pumpAndSettle();
      expect(find.text('Batch ROM Forwarder Generator'), findsOneWidget);

      // Navigate to Keys Manager Screen
      await tester.tap(find.text('Keys Manager'));
      await tester.pumpAndSettle();
      expect(find.text('Key Diagnostics & Status'), findsOneWidget);

      // Enter raw keys into editor
      await tester.enterText(
        find.byType(TextField).last,
        'header_key = 11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff\nsd_seed = aabbccddeeff00112233445566778899\ntitlekdk_00 = 00112233445566778899aabbccddeeff\nkey_area_key_application_00 = 1234567890abcdef1234567890abcdef',
      );
      await tester.tap(find.text('SAVE KEYS'));
      await tester.pumpAndSettle();

      // Keys ready pill should now be active
      expect(find.text('KEYS READY'), findsOneWidget);

      // Navigate to Guide Screen
      await tester.tap(find.text('Guide & Parity'));
      await tester.pumpAndSettle();
      expect(find.text('Installation & Ban Safety Guide'), findsOneWidget);
    });
  });
}
