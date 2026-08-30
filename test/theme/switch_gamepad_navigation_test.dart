// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/theme/switch_gamepad_navigation.dart';
import 'package:nspff/theme/switch_theme.dart';

void main() {
  group('SwitchButtonLegend', () {
    Widget buildLegend(
      WidgetTester tester, {
      int currentTabIndex = 0,
      VoidCallback? onPrevTab,
      VoidCallback? onNextTab,
      VoidCallback? onConfirm,
      VoidCallback? onBack,
      VoidCallback? onQuickAction,
      VoidCallback? onBrowse,
      VoidCallback? onStart,
    }) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: SwitchGamepadScope(
          initialGamepadConnected: true,
          child: Scaffold(
            bottomNavigationBar: SwitchButtonLegend(
              currentTabIndex: currentTabIndex,
              forceVisible: true,
              onPrevTab: onPrevTab,
              onNextTab: onNextTab,
              onConfirm: onConfirm,
              onBack: onBack,
              onQuickAction: onQuickAction,
              onBrowse: onBrowse,
              onStart: onStart,
            ),
          ),
        ),
      );
    }

    testWidgets('renders A/B/X/Y/Plus/L/R badges on forwarder tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildLegend(tester));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('X'), findsOneWidget);
      expect(find.text('Y'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('hides X and Y badges on non-forwarder tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildLegend(tester, currentTabIndex: 3));
      await tester.pumpAndSettle();

      expect(find.text('X'), findsNothing);
      expect(find.text('Y'), findsNothing);
    });

    testWidgets('Start (+) badge dispatches GamepadStartIntent',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: SwitchGamepadScope(
            initialGamepadConnected: true,
            child: Scaffold(
              body: const Center(child: Text('No screen actions')),
              bottomNavigationBar: Builder(
                builder: (context) => SwitchButtonLegend(
                  forceVisible: true,
                  currentTabIndex: 0,
                  onStart: () => Actions.maybeInvoke<GamepadStartIntent>(
                    context,
                    const GamepadStartIntent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No gamepad action bound for Start (+)'),
          findsOneWidget);
    });

    testWidgets('X badge dispatches GamepadQuickActionIntent',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: SwitchGamepadScope(
            initialGamepadConnected: true,
            child: Scaffold(
              body: const Center(child: Text('No screen actions')),
              bottomNavigationBar: Builder(
                builder: (context) => SwitchButtonLegend(
                  forceVisible: true,
                  currentTabIndex: 0,
                  onQuickAction: () =>
                      Actions.maybeInvoke<GamepadQuickActionIntent>(
                    context,
                    const GamepadQuickActionIntent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('X'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No gamepad action bound for Quick (X)'),
          findsOneWidget);
    });

    testWidgets('Y badge dispatches GamepadBrowseIntent',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: SwitchGamepadScope(
            initialGamepadConnected: true,
            child: Scaffold(
              body: const Center(child: Text('No screen actions')),
              bottomNavigationBar: Builder(
                builder: (context) => SwitchButtonLegend(
                  forceVisible: true,
                  currentTabIndex: 0,
                  onBrowse: () => Actions.maybeInvoke<GamepadBrowseIntent>(
                    context,
                    const GamepadBrowseIntent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Y'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No gamepad action bound for Browse (Y)'),
          findsOneWidget);
    });
  });
}
