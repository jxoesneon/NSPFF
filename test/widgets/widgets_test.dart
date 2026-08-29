// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/models/retroarch_core.dart';
import 'package:nspff/theme/switch_theme.dart';
import 'package:nspff/widgets/icon_preview_picker.dart';
import 'package:nspff/widgets/switch_button.dart';
import 'package:nspff/widgets/switch_card.dart';
import 'package:nspff/widgets/switch_dropdown.dart';
import 'package:nspff/widgets/switch_text_field.dart';
import 'package:nspff/widgets/switch_toggle.dart';
import 'package:nspff/widgets/title_id_input.dart';

void main() {
  group('Widget Component Tests', () {
    testWidgets('SwitchCard renders title, subtitle, and child', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SwitchTheme.darkTheme,
          home: const Scaffold(
            body: SwitchCard(
              title: 'Card Title',
              subtitle: 'Card Subtitle',
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Title'), findsOneWidget);
      expect(find.text('Card Subtitle'), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('SwitchButton renders variants and triggers tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SwitchTheme.darkTheme,
          home: Scaffold(
            body: SwitchButton(
              text: 'Click Me',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
      await tester.tap(find.text('Click Me'));
      expect(tapped, isTrue);
    });

    testWidgets('SwitchTextField normalizes path input correctly', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: SwitchTheme.darkTheme,
          home: Scaffold(
            body: SwitchTextField(
              label: 'Path Input',
              controller: controller,
              isPath: true,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'C:\\switch\\app.nro');
      expect(controller.text, equals('/switch/app.nro'));
    });

    testWidgets('SwitchToggle triggers value change', (WidgetTester tester) async {
      bool val = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SwitchTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) => SwitchToggle(
                title: 'Toggle Setting',
                value: val,
                onChanged: (n) => setState(() => val = n),
              ),
            ),
          ),
        ),
      );

      expect(val, isFalse);
      await tester.tap(find.byType(Switch));
      expect(val, isTrue);
    });

    testWidgets('TitleIdInput validates 16-hex characters and randomizes', (WidgetTester tester) async {
      final controller = TextEditingController(text: '0500000000000001');

      await tester.pumpWidget(
        MaterialApp(
          theme: SwitchTheme.darkTheme,
          home: Scaffold(
            body: TitleIdInput(
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('0500000000000001'), findsOneWidget);
      await tester.tap(find.text('Randomize'));
      await tester.pump();

      expect(controller.text.length, equals(16));
      expect(RegExp(r'^[0-9A-F]{16}$').hasMatch(controller.text), isTrue);
    });

    testWidgets('RetroArchCoreDropdown renders and selects core', (WidgetTester tester) async {
      RetroArchCore? selected = RetroArchCore.builtInCores.first;

      await tester.pumpWidget(
        MaterialApp(
          theme: SwitchTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) => RetroArchCoreDropdown(
                selectedCore: selected,
                onChanged: (c) => setState(() => selected = c),
              ),
            ),
          ),
        ),
      );

      expect(find.text(selected!.displayName), findsOneWidget);
    });

    testWidgets('LogoTypeDropdown renders all logo types', (WidgetTester tester) async {
      LogoType logo = LogoType.nintendo;

      await tester.pumpWidget(
        MaterialApp(
          theme: SwitchTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) => LogoTypeDropdown(
                selectedLogo: logo,
                onChanged: (l) => setState(() => logo = l),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nintendo'), findsOneWidget);
    });
  });
}
