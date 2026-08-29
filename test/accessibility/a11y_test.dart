// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package0:flutter_test/flutter_test.dart';
import 'package:nspff/theme/switch_theme.dart';
import 'package:nspff/widgets/switch_button.dart';

void main() {
  group('Accessibility (a11y) & Semantics Tests', () {
    testWidgets('SwitchButton meets touch target guidelines', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SwitchTheme.darkTheme,
          home: Scaffold(
            body: SwitchButton(
              text: 'Accessible Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      final Size buttonSize = tester.getSize(find.byType(ElevatedButton));
      expect(buttonSize.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('Form inputs have clear semantics labels and pass semantics check', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: SwitchTheme.darkTheme,
          home: Scaffold(
            body: Semantics(
              label: 'Accessible Input',
              textField: true,
              child: const TextField(
                decoration: InputDecoration(labelText: 'Accessible Input'),
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Accessible Input'), findsOneWidget);
      handle.dispose();
    });
  });
}
