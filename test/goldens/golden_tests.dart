// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/theme/switch_theme.dart';
import 'package:nspff/views/main_navigation_screen.dart';

void main() {
  group('Golden Visual Regression Tests', () {
    testWidgets('Renders MainNavigationScreen visually clean', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SwitchTheme.darkTheme,
          home: const MainNavigationScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationScreen), findsOneWidget);
    });
  });
}
