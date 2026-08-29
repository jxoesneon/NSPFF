// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/theme/switch_theme.dart';
import 'package:nspff/views/batch_generator_screen.dart';
import 'package:nspff/views/guide_screen.dart';
import 'package:nspff/views/keys_manager_screen.dart';
import 'package:nspff/views/main_navigation_screen.dart';
import 'package:nspff/views/nro_forwarder_screen.dart';
import 'package:nspff/views/preset_history_screen.dart';
import 'package:nspff/views/retroarch_forwarder_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Full Application Views Tests', () {
    testWidgets('MainNavigationScreen renders tab bar and navigates tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MainNavigationScreen(),
        ),
      );

      expect(find.text('NSPFF'), findsOneWidget);
      expect(find.text('FAST FORWARD'), findsOneWidget);
      expect(find.text('NRO Apps'), findsOneWidget);
      expect(find.text('RetroArch'), findsOneWidget);

      // Tap RetroArch Tab
      await tester.tap(find.text('RetroArch'));
      await tester.pumpAndSettle();
      expect(find.text('RetroArch ROM Forwarder'), findsOneWidget);

      // Tap Batch Tab
      await tester.tap(find.text('Batch ROMs'));
      await tester.pumpAndSettle();
      expect(find.text('Batch ROM Forwarder Generator'), findsOneWidget);

      // Tap Keys Tab
      await tester.tap(find.text('Keys Manager'));
      await tester.pumpAndSettle();
      expect(find.text('Key Diagnostics & Status'), findsOneWidget);

      // Tap History Tab
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Generation History & Saved Profiles'), findsOneWidget);

      // Tap Guide Tab
      await tester.tap(find.text('Guide & Parity'));
      await tester.pumpAndSettle();
      expect(find.text('Installation & Ban Safety Guide'), findsOneWidget);
    });

    testWidgets('NroForwarderScreen renders form components', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: NroForwarderScreen()),
        ),
      );

      expect(find.text('NRO Forwarder Generator'), findsOneWidget);
      expect(find.text('Smart Auto-Fill'), findsOneWidget);
      expect(find.text('Target NRO Path on SD Card'), findsOneWidget);
      expect(find.text('GENERATE NSP FORWARDER'), findsOneWidget);
    });

    testWidgets('RetroArchForwarderScreen renders core options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: RetroArchForwarderScreen()),
        ),
      );

      expect(find.text('RetroArch ROM Forwarder'), findsOneWidget);
      expect(find.text('Smart Auto-Fill'), findsOneWidget);
      expect(find.text('GENERATE RETROARCH NSP'), findsOneWidget);
    });

    testWidgets('BatchGeneratorScreen renders batch form', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: BatchGeneratorScreen()),
        ),
      );

      expect(find.text('Batch ROM Forwarder Generator'), findsOneWidget);
      expect(find.text('Smart Auto-Format List'), findsOneWidget);
      expect(find.text('RUN BATCH GENERATION'), findsOneWidget);
    });

    testWidgets('KeysManagerScreen renders diagnostics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: KeysManagerScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Key Diagnostics & Status'), findsOneWidget);
      expect(find.text('SAVE KEYS'), findsOneWidget);
    });

    testWidgets('PresetHistoryScreen handles empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: PresetHistoryScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('No generated forwarders in history yet.'), findsOneWidget);
    });

    testWidgets('GuideScreen renders guide steps and parity matrix', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: GuideScreen()),
        ),
      );

      expect(find.text('Installation & Ban Safety Guide'), findsOneWidget);
      expect(find.text('Parity & Feature Comparison'), findsOneWidget);
    });
  });
}
