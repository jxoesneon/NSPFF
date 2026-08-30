// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/keys_service.dart';
import 'package:nspff/theme/switch_gamepad_navigation.dart';
import 'package:nspff/theme/switch_theme.dart';
import 'package:nspff/views/batch_generator_screen.dart';
import 'package:nspff/views/main_navigation_screen.dart';
import 'package:nspff/widgets/switch_button.dart';
import 'package:nspff/widgets/switch_card.dart';
import 'package:nspff/widgets/switch_toggle.dart';
import 'package:nspff/widgets/switch_text_field.dart';
import 'package:nspff/widgets/title_id_input.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deterministic file picker that returns a fixed list of [PlatformFile]s.
class _MockFilePicker extends FilePickerIO {
  final List<PlatformFile> _files;

  _MockFilePicker(this._files);

  @override
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileLoading,
    bool? allowCompression = true,
    bool allowMultiple = false,
    bool? withData = false,
    int compressionQuality = 30,
    bool? withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return FilePickerResult(_files);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp(
    Widget child, {
    KeysService? keysService,
    bool? initialGamepadConnected,
  }) {
    return ChangeNotifierProvider<KeysService>.value(
      value: keysService ?? KeysService(),
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: SwitchGamepadScope(
          initialGamepadConnected: initialGamepadConnected,
          child: child,
        ),
      ),
    );
  }

  group('Gamepad Shortcuts & Intents Mapping Tests', () {
    test('Verify all Nintendo Switch controller keys are mapped', () {
      final shortcuts = switchGamepadShortcuts;

      // A / Select / Enter -> Confirm
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.gameButtonA)],
        isA<GamepadConfirmIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.select)],
        isA<GamepadConfirmIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.enter)],
        isA<GamepadConfirmIntent>(),
      );

      // B / Escape / Backspace -> Back
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.gameButtonB)],
        isA<GamepadBackIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.escape)],
        isA<GamepadBackIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.backspace)],
        isA<GamepadBackIntent>(),
      );

      // X -> Quick Action
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.gameButtonX)],
        isA<GamepadQuickActionIntent>(),
      );

      // Y -> Browse
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.gameButtonY)],
        isA<GamepadBrowseIntent>(),
      );

      // L / R -> Tab Navigation
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.gameButtonLeft1)],
        isA<GamepadPrevTabIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.gameButtonRight1)],
        isA<GamepadNextTabIntent>(),
      );

      // + / Start -> Generate NSP
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.gameButtonStart)],
        isA<GamepadStartIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(LogicalKeyboardKey.contextMenu)],
        isA<GamepadStartIntent>(),
      );
    });
  });

  group('MainNavigationScreen Gamepad L / R Bumper Tab Switching Tests', () {
    testWidgets('L and R shoulder buttons cycle through tabs correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(const MainNavigationScreen()),
      );
      await tester.pumpAndSettle();

      // Initial tab: Tab 0 (NRO Apps)
      expect(find.text('NRO Forwarder Generator'), findsOneWidget);

      // Press R (gameButtonRight1): switches to Tab 1 (RetroArch)
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonRight1);
      await tester.pumpAndSettle();
      expect(find.text('RetroArch ROM Forwarder'), findsOneWidget);

      // Press R (gameButtonRight1): switches to Tab 2 (Batch ROMs)
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonRight1);
      await tester.pumpAndSettle();
      expect(find.text('Batch ROM Forwarder Generator'), findsOneWidget);

      // Press L (gameButtonLeft1): switches back to Tab 1 (RetroArch)
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonLeft1);
      await tester.pumpAndSettle();
      expect(find.text('RetroArch ROM Forwarder'), findsOneWidget);

      // Press L (gameButtonLeft1): switches back to Tab 0 (NRO Apps)
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonLeft1);
      await tester.pumpAndSettle();
      expect(find.text('NRO Forwarder Generator'), findsOneWidget);

      // Press L (gameButtonLeft1) at Tab 0: wraps around to Tab 5 (Guide & Parity)
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonLeft1);
      await tester.pumpAndSettle();
      expect(find.text('Installation & Ban Safety Guide'), findsOneWidget);

      // Press R (gameButtonRight1) at Tab 5: wraps around to Tab 0 (NRO Apps)
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonRight1);
      await tester.pumpAndSettle();
      expect(find.text('NRO Forwarder Generator'), findsOneWidget);
    });
  });

  group('A Button Activation Tests', () {
    testWidgets('gameButtonA triggers SwitchButton onPressed when focused',
        (WidgetTester tester) async {
      bool buttonPressed = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Center(
              child: SwitchButton(
                text: 'Build Forwarder',
                focusNode: focusNode,
                autofocus: true,
                onPressed: () {
                  buttonPressed = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);

      // Send gameButtonA key event
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pumpAndSettle();

      expect(buttonPressed, isTrue);
    });

    testWidgets('Select and Enter keys also trigger SwitchButton activation',
        (WidgetTester tester) async {
      int activations = 0;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Center(
              child: SwitchButton(
                text: 'Confirm Action',
                focusNode: focusNode,
                autofocus: true,
                onPressed: () {
                  activations++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter key
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(activations, equals(1));

      // Select key
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(activations, equals(2));
    });
  });

  group('Interactive Widgets Focus & Gamepad Traversal Tests', () {
    testWidgets('SwitchToggle toggles value on gameButtonA when focused',
        (WidgetTester tester) async {
      bool toggleValue = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        buildTestApp(
          StatefulBuilder(
            builder: (ctx, setState) => Scaffold(
              body: SwitchToggle(
                title: 'Screenshot Capture',
                value: toggleValue,
                focusNode: focusNode,
                autofocus: true,
                onChanged: (val) {
                  setState(() => toggleValue = val);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
      expect(toggleValue, isFalse);

      // Press A to toggle
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pumpAndSettle();

      expect(toggleValue, isTrue);

      // Press A again to toggle back
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pumpAndSettle();

      expect(toggleValue, isFalse);
    });

    testWidgets('SwitchCard triggers onTap on gameButtonA when focused',
        (WidgetTester tester) async {
      bool cardTapped = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: SwitchCard(
              title: 'Interactive Card',
              subtitle: 'Press A to open',
              focusNode: focusNode,
              autofocus: true,
              onTap: () {
                cardTapped = true;
              },
              child: const Text('Card Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pumpAndSettle();

      expect(cardTapped, isTrue);
    });

    testWidgets('SwitchTextField shows cyan neon glow when focused',
        (WidgetTester tester) async {
      final controller = TextEditingController(text: '/switch/hbmenu.nro');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: SwitchTextField(
              label: 'NRO Path',
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);

      // Find the AnimatedContainer wrapping the TextField
      final containerFinder = find.descendant(
        of: find.byType(SwitchTextField),
        matching: find.byType(AnimatedContainer),
      );
      expect(containerFinder, findsOneWidget);

      final containerWidget = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;

      // Verify neon glow border
      expect(
          (decoration.border as Border).top.color, equals(AppTheme.switchCyan));
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.first.color,
          equals(AppTheme.switchCyan.withValues(alpha: 0.5)));
    });

    testWidgets('TitleIdInput Randomize button can be activated via Gamepad',
        (WidgetTester tester) async {
      final controller = TextEditingController(text: '0500000000000001');
      final randomizeFocus = FocusNode();

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: TitleIdInput(
              controller: controller,
              randomizeFocusNode: randomizeFocus,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the randomize button
      randomizeFocus.requestFocus();
      await tester.pumpAndSettle();
      expect(randomizeFocus.hasFocus, isTrue);

      // Press A to trigger randomize
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pumpAndSettle();

      expect(controller.text.length, equals(16));
      expect(controller.text, isNot(equals('0500000000000001')));
    });

    testWidgets(
        'Gamepad Button Legend stays hidden when no gamepad connected and appears when connected',
        (WidgetTester tester) async {
      bool prevTapped = false;
      bool nextTapped = false;

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            bottomNavigationBar: SwitchButtonLegend(
              onPrevTab: () => prevTapped = true,
              onNextTab: () => nextTapped = true,
            ),
          ),
          initialGamepadConnected: false,
        ),
      );
      await tester.pumpAndSettle();

      // Legend must NOT be visible when no gamepad is connected
      expect(find.text('Tabs'), findsNothing);
      expect(find.text('Select'), findsNothing);

      // Press any Gamepad button -> Auto-detects connected gamepad
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pumpAndSettle();

      // Legend now dynamically appears!
      expect(find.text('Tabs'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Generate'), findsOneWidget);

      // Tap L badge
      await tester.tap(find.text('L'));
      expect(prevTapped, isTrue);

      // Tap R badge
      await tester.tap(find.text('R'));
      expect(nextTapped, isTrue);
    });
  });

  group('MainNavigationScreen Gamepad Legend Tests', () {
    testWidgets('Legend X badge dispatches Quick intent from MainNavigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MainNavigationScreen(),
          initialGamepadConnected: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('X'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No gamepad action bound for Quick (X)'),
          findsOneWidget);
    });

    testWidgets('Legend Y badge dispatches Browse intent from MainNavigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MainNavigationScreen(),
          initialGamepadConnected: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Y'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No gamepad action bound for Browse (Y)'),
          findsOneWidget);
    });

    testWidgets('Legend + badge dispatches Start intent from MainNavigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MainNavigationScreen(),
          initialGamepadConnected: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No gamepad action bound for Start (+)'),
          findsOneWidget);
    });
  });

  group('BatchGeneratorScreen Gamepad Intent Tests', () {
    testWidgets('gameButtonStart triggers batch generation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(const Scaffold(body: BatchGeneratorScreen())),
      );
      await tester.pumpAndSettle();

      // Press + / Start
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonStart);
      await tester.pumpAndSettle();

      expect(
        find.text('Valid prod.keys required! Please import keys in Keys Manager.'),
        findsOneWidget,
      );
    });

    testWidgets('gameButtonX triggers auto-format quick action',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(const Scaffold(body: BatchGeneratorScreen())),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonX);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Auto-formatted batch ROM paths & cleaned titles!'),
        findsOneWidget,
      );
    });

    testWidgets('gameButtonY triggers multi-ROM picker browse',
        (WidgetTester tester) async {
      // Replace file_picker with a deterministic mock for the test.
      FilePicker.platform = _MockFilePicker([
        PlatformFile(
          name: 'Mega Man X.sfc',
          path: '/fake/Mega Man X.sfc',
          size: 1024,
        ),
      ]);
      addTearDown(FilePickerIO.registerWith);

      await tester.pumpWidget(
        buildTestApp(const Scaffold(body: BatchGeneratorScreen())),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonY);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Added 1 ROMs to the batch!'),
        findsOneWidget,
      );
    });
  });

  group('SwitchGamepadScope Fallback Action Tests', () {
    testWidgets('Unbound gamepad actions show a safe fallback SnackBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: Center(child: Text('No screen actions')),
          ),
          initialGamepadConnected: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonStart);
      await tester.pumpAndSettle();

      expect(find.textContaining('No gamepad action bound'), findsOneWidget);
    });
  });
}
