// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nspff/services/keys_service.dart';
import 'package:nspff/theme/switch_icons.dart';
import 'package:nspff/theme/switch_theme.dart';
import 'package:nspff/views/main_navigation_screen.dart';
import 'package:nspff/widgets/switch_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Golden Visual Regression Tests', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      SwitchIcons.initResolver();
      KeysService.setForceFallback(true);
      KeysService.clearTestFallback();
    });

    tearDown(() {
      KeysService.setForceFallback(false);
      KeysService.clearTestFallback();
    });

    testWidgets('MainNavigationScreen matches golden baseline',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<KeysService>.value(
          value: KeysService(),
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MainNavigationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MainNavigationScreen),
        matchesGoldenFile('goldens/main_navigation_screen.png'),
      );
    });

    testWidgets('SwitchCard matches golden baseline',
        (WidgetTester tester) async {
      // Use a focused, phone-sized viewport for the card golden.
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: SwitchCard(
                title: 'Golden Card Header',
                subtitle: 'Golden Card Subtitle Text',
                trailing: Icon(Icons.keyboard_arrow_down),
                child: Text('Card Body Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SwitchCard),
        matchesGoldenFile('goldens/switch_card.png'),
      );
    });
  });
}
