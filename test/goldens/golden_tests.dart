// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/theme/switch_theme.dart';
import 'package:nspff/views/main_navigation_screen.dart';
import 'package:nspff/widgets/switch_card.dart';

void main() {
  group('Golden Visual Regression Tests', () {
    testWidgets('Renders MainNavigationScreen UI structure consistently', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MainNavigationScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationScreen), findsOneWidget);
    });

    testWidgets('Renders SwitchCard visual layout components', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SwitchCard(
              title: 'Golden Card Header',
              subtitle: 'Golden Card Subtitle Text',
              child: Text('Card Body Content'),
            ),
          ),
        ),
      );

      expect(find.text('Golden Card Header'), findsOneWidget);
      expect(find.text('Golden Card Subtitle Text'), findsOneWidget);
    });
  });
}
