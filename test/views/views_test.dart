// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/models/prod_keys.dart';
import 'package:nspff/services/batch_processor_service.dart';
import 'package:nspff/services/nsp_generator.dart';
import 'package:nspff/services/preset_service.dart';
import 'package:nspff/theme/switch_icons.dart';
import 'package:nspff/theme/switch_theme.dart';
import 'package:nspff/views/batch_generator_screen.dart';
import 'package:nspff/views/guide_screen.dart';
import 'package:nspff/views/keys_manager_screen.dart';
import 'package:nspff/views/main_navigation_screen.dart';
import 'package:nspff/views/nro_forwarder_screen.dart';
import 'package:nspff/views/preset_history_screen.dart';
import 'package:nspff/views/retroarch_forwarder_screen.dart';
import 'package:nspff/widgets/switch_button.dart';
import 'package:nspff/widgets/switch_card.dart';
import 'package:nspff/widgets/switch_text_field.dart';
import 'package:nspff/widgets/switch_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';
import 'package:nspff/services/keys_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    SwitchIcons.initResolver();
    KeysService.setForceFallback(true);
    KeysService.clearTestFallback();
  });

  tearDown(() {
    KeysService.setForceFallback(false);
    KeysService.clearTestFallback();
  });

  Widget createTestWidget(Widget child, [KeysService? keysService]) {
    return ChangeNotifierProvider<KeysService>.value(
      value: keysService ?? KeysService(),
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: child,
      ),
    );
  }

  Future<void> enterSwitchText(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    final fieldFinder = find.widgetWithText(SwitchTextField, label);
    expect(fieldFinder, findsOneWidget);
    final inputFinder = find.descendant(
      of: fieldFinder,
      matching: find.byType(EditableText),
    );
    await tester.enterText(inputFinder, text);
    await tester.pump();
  }

  SwitchButton primarySwitchButton(WidgetTester tester, String text) {
    final finder = find.widgetWithText(SwitchButton, text);
    return tester.widget<SwitchButton>(finder);
  }

  Future<void> toggleAdvancedOption(
    WidgetTester tester,
    String optionTitle,
  ) async {
    final cardFinder = find.widgetWithText(SwitchCard, 'Advanced Options');
    final expandFinder = find.descendant(
      of: cardFinder,
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(expandFinder);
    await tester.pumpAndSettle();
    await tester.tap(expandFinder);
    await tester.pumpAndSettle();

    final toggleFinder = find.widgetWithText(SwitchToggle, optionTitle);
    await tester.ensureVisible(toggleFinder);
    await tester.pumpAndSettle();
    final switchFinder = find.descendant(
      of: toggleFinder,
      matching: find.byType(Switch),
    );
    await tester.tap(switchFinder);
    await tester.pump();
  }

  group('Full Application Views Tests', () {
    testWidgets('MainNavigationScreen renders tab bar and navigates tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const MainNavigationScreen()),
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

    testWidgets('NroForwarderScreen renders form components',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: NroForwarderScreen())),
      );

      expect(find.text('NRO Forwarder Generator'), findsOneWidget);
      expect(find.text('Smart Auto-Fill'), findsOneWidget);
      expect(find.text('Target NRO Path on SD Card'), findsOneWidget);
      expect(find.text('GENERATE NSP FORWARDER'), findsOneWidget);
    });

    testWidgets('RetroArchForwarderScreen renders core options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: RetroArchForwarderScreen())),
      );

      expect(find.text('RetroArch ROM Forwarder'), findsOneWidget);
      expect(find.text('Smart Auto-Fill'), findsOneWidget);
      expect(find.text('GENERATE RETROARCH NSP'), findsOneWidget);
    });

    testWidgets('BatchGeneratorScreen renders batch form',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: BatchGeneratorScreen())),
      );

      expect(find.text('Batch ROM Forwarder Generator'), findsOneWidget);
      expect(find.text('AUTO-FORMAT'), findsOneWidget);
      expect(find.text('RUN BATCH GENERATION'), findsOneWidget);
    });

    testWidgets('BatchGeneratorScreen wraps body in Actions for gamepad intents',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: BatchGeneratorScreen())),
      );

      // The screen should now expose an Actions widget that maps gamepad
      // Start (+), Quick (X), and Browse (Y) intents.
      final batchActions = find.byWidgetPredicate(
        (widget) =>
            widget is Actions &&
            widget.actions.keys
                .any((type) => type.toString() == 'GamepadStartIntent'),
      );
      expect(batchActions, findsOneWidget);
      expect(find.text('Batch ROM Forwarder Generator'), findsOneWidget);
    });

    testWidgets('KeysManagerScreen renders diagnostics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: KeysManagerScreen())),
      );

      await tester.pumpAndSettle();
      expect(find.text('Key Diagnostics & Status'), findsOneWidget);
      expect(find.text('SAVE KEYS'), findsOneWidget);
    });

    testWidgets('PresetHistoryScreen handles empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: PresetHistoryScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(
          find.text('No generated forwarders in history yet.'), findsOneWidget);
    });

    testWidgets('PresetHistoryScreen renders and clears saved history',
        (WidgetTester tester) async {
      final config = ForwarderConfig(
        id: '0500000000000001',
        title: 'Test Homebrew',
        publisher: 'Homebrew Dev',
        nroPath: '/switch/test.nro',
      );
      await SavedPresetService.addToHistory(config);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: PresetHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Homebrew'), findsOneWidget);
      expect(find.textContaining('1 previously created NSP forwarders'),
          findsOneWidget);
      expect(find.textContaining('/switch/test.nro'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();

      expect(find.text('No generated forwarders in history yet.'), findsOneWidget);
      expect(find.text('Test Homebrew'), findsNothing);
    });

    testWidgets('GuideScreen renders guide steps and parity matrix',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: GuideScreen()),
        ),
      );

      expect(find.text('Installation & Ban Safety Guide'), findsOneWidget);
      expect(find.text('Parity & Feature Comparison'), findsOneWidget);
    });

    testWidgets(
        'NroForwarderScreen enters title/publisher, toggles options, '
        'and enables generate button only with required fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: NroForwarderScreen())),
      );
      await tester.pumpAndSettle();

      // Enter text into title and publisher fields.
      await enterSwitchText(tester, 'Application Title', 'My Homebrew');
      await enterSwitchText(tester, 'Publisher / Author', 'Homebrew Dev');

      // Expand advanced options and toggle a switch option.
      await toggleAdvancedOption(tester, 'Enable SVC Debug');
      final toggleFinder = find.widgetWithText(SwitchToggle, 'Enable SVC Debug');
      final switchFinder = find.descendant(
        of: toggleFinder,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      // Required fields are populated, so the primary action is enabled.
      final button = primarySwitchButton(tester, 'GENERATE NSP FORWARDER');
      expect(button.onPressed, isNotNull);

      // Clearing a required field disables the primary action.
      await enterSwitchText(tester, 'Application Title', '');
      final disabledButton = primarySwitchButton(tester, 'GENERATE NSP FORWARDER');
      expect(disabledButton.onPressed, isNull);

      // Restoring the required field re-enables the primary action.
      await enterSwitchText(tester, 'Application Title', 'My Homebrew');
      final enabledButton = primarySwitchButton(tester, 'GENERATE NSP FORWARDER');
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets(
        'RetroArchForwarderScreen enters title/publisher, toggles options, '
        'and enables generate button only with required fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: RetroArchForwarderScreen())),
      );
      await tester.pumpAndSettle();

      // Enter text into title and publisher fields.
      await enterSwitchText(tester, 'Game Title', 'Chrono Trigger');
      await enterSwitchText(tester, 'Publisher / System', 'SNES / RetroArch');

      // Expand advanced options and toggle a switch option.
      await toggleAdvancedOption(tester, 'Enable SVC Debug');
      final toggleFinder = find.widgetWithText(SwitchToggle, 'Enable SVC Debug');
      final switchFinder = find.descendant(
        of: toggleFinder,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      // Required fields are populated, so the primary action is enabled.
      final button = primarySwitchButton(tester, 'GENERATE RETROARCH NSP');
      expect(button.onPressed, isNotNull);

      // Clearing a required field disables the primary action.
      await enterSwitchText(tester, 'Game Title', '');
      final disabledButton = primarySwitchButton(tester, 'GENERATE RETROARCH NSP');
      expect(disabledButton.onPressed, isNull);

      // Restoring the required field re-enables the primary action.
      await enterSwitchText(tester, 'Game Title', 'Chrono Trigger');
      final enabledButton = primarySwitchButton(tester, 'GENERATE RETROARCH NSP');
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets(
        'NroForwarderScreen Smart Auto-Fill populates title and publisher',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: NroForwarderScreen())),
      );
      await tester.pumpAndSettle();

      await enterSwitchText(
          tester, 'Target NRO Path on SD Card', '/switch/hbmenu.nro');

      // Tap the Smart Auto-Fill button and wait for the SnackBar.
      await tester.tap(find.text('Smart Auto-Fill'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Auto-detected'), findsOneWidget);
      expect(
        find.widgetWithText(SwitchTextField, 'Application Title'),
        findsOneWidget,
      );
      final titleInput = find.descendant(
        of: find.widgetWithText(SwitchTextField, 'Application Title'),
        matching: find.byType(EditableText),
      );
      expect(
          tester.widget<EditableText>(titleInput).controller.text, isNotEmpty);
    });

    testWidgets(
        'RetroArchForwarderScreen Smart Auto-Fill populates game details',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: RetroArchForwarderScreen())),
      );
      await tester.pumpAndSettle();

      // Entering a ROM path triggers auto-detect on change.
      await enterSwitchText(
          tester, 'Target ROM Path on SD Card', '/roms/snes/Mega Man X.sfc');
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(SwitchTextField, 'Game Title'),
        findsOneWidget,
      );
      final titleInput = find.descendant(
        of: find.widgetWithText(SwitchTextField, 'Game Title'),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(titleInput).controller.text,
          contains('Mega Man'));
    });

    testWidgets(
        'BatchGeneratorScreen adding and removing batch items updates the list',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: BatchGeneratorScreen())),
      );
      await tester.pumpAndSettle();

      // Primary action is enabled because the default batch list is non-empty.
      final enabledButton = primarySwitchButton(tester, 'RUN BATCH GENERATION');
      expect(enabledButton.onPressed, isNotNull);

      // Clear the batch list and confirm it is empty and the button is disabled.
      await tester.tap(find.byIcon(Icons.clear_all));
      await tester.pump();

      final listField = find.widgetWithText(SwitchTextField, 'ROM Paths List');
      final listInput = find.descendant(
        of: listField,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(listInput).controller.text, isEmpty);

      final disabledButton = primarySwitchButton(tester, 'RUN BATCH GENERATION');
      expect(disabledButton.onPressed, isNull);

      // Add a new batch item and confirm the list and primary action update.
      await tester.enterText(listInput, '/roms/snes/Mega Man X.sfc');
      await tester.pump();

      expect(tester.widget<EditableText>(listInput).controller.text,
          contains('Mega Man X'));
      final reEnabledButton = primarySwitchButton(tester, 'RUN BATCH GENERATION');
      expect(reEnabledButton.onPressed, isNotNull);
    });

    testWidgets(
        'BatchGeneratorScreen renders Cancelled status when batch is cancelled',
        (WidgetTester tester) async {
      // Use a tall viewport so the batch buttons are on-screen without
      // expensive scrolling.
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Seed valid prod.keys so the batch can start.
      const rawKeys =
          'header_key = 11223344556677889900aabbccddeeff\n'
          'sd_seed = aabbccddeeff00112233445566778899\n'
          'titlekdk_00 = 00112233445566778899aabbccddeeff';
      await KeysService.saveRawKeys(rawKeys);
      final keysService = KeysService();
      await keysService.init();

      // Provide a controlled batch processor so the worker pauses until the
      // test has cancelled the batch, then verifies the cancelled status path.
      final batchStarted = Completer<void>();
      final batchContinue = Completer<void>();
      final processor = BatchProcessorService(
        customGenerator: ({
          required ForwarderConfig config,
          required ProdKeys keys,
        }) async {
          batchStarted.complete();
          await batchContinue.future;
          return GeneratedNspResult(
            nspBytes: Uint8List(0),
            filename: 'test.nsp',
            titleId: '0500000000000000',
            totalSize: 0,
          );
        },
      );

      await tester.pumpWidget(
        createTestWidget(
          Scaffold(body: BatchGeneratorScreen(batchProcessor: processor)),
          keysService,
        ),
      );
      await tester.pumpAndSettle();

      // Replace the default multi-line list with a single item.
      final listField = find.widgetWithText(SwitchTextField, 'ROM Paths List');
      final listInput = find.descendant(
        of: listField,
        matching: find.byType(EditableText),
      );
      await tester.enterText(listInput, '/roms/snes/Test Game.sfc');
      await tester.pump();

      // Start the batch and wait for the controlled worker to begin.
      await tester.tap(find.text('RUN BATCH GENERATION'));
      await tester.pump();
      await batchStarted.future;

      expect(find.text('CANCEL BATCH'), findsOneWidget);

      // Cancel the batch and allow the worker to finish; because the worker
      // observes the cancellation flag after returning, it is marked cancelled.
      await tester.tap(find.text('CANCEL BATCH'));
      batchContinue.complete();
      await tester.pumpAndSettle();

      // The cancellation SnackBar is shown first; pump through its display
      // duration so the final "Batch cancelled" summary is rendered.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.textContaining('Batch cancelled'), findsOneWidget);
    });
  });
}
