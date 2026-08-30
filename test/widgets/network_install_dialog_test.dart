// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/network_install_service.dart';
import 'package:nspff/theme/switch_theme.dart';
import 'package:nspff/widgets/network_install_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = null;
  });

  late NetworkInstallService service;

  setUp(() async {
    service = NetworkInstallService.instance;
    service.enableIdleTimeout = false;
    await service.stopServer();
    service.clearNsps();
  });

  tearDown(() async {
    await service.stopServer();
    service.clearNsps();
    service.enableIdleTimeout = true;
  });

  Widget buildTestDialog({String? targetFilename}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => NetworkInstallDialog.show(
              context,
              targetFilename: targetFilename,
            ),
            child: const Text('OPEN DIALOG'),
          ),
        ),
      ),
    );
  }

  group('NetworkInstallDialog Widget Tests', () {
    testWidgets(
        'Renders Horizon OS styled header, status, QR code and instructions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      await tester.pumpWidget(buildTestDialog());

      // Open the dialog
      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('WIRELESS CONSOLE INSTALLER'), findsOneWidget);
      expect(find.text('Embedded Stream Server'), findsOneWidget);
      expect(find.text('HOW TO INSTALL'), findsOneWidget);
      expect(find.text('DBI Installer'), findsOneWidget);
      expect(find.text('Tinfoil'), findsOneWidget);
      expect(find.text('Awoo / TinWoo'), findsOneWidget);
      expect(find.text('Web Browser & PC'), findsOneWidget);
      expect(find.textContaining('Open DBI on your Nintendo Switch'),
          findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('COPY URL'), findsOneWidget);

      // Verify QR Code widget is present
      expect(find.byType(QrImageView), findsOneWidget);

      // Test expanding Tinfoil accordion
      await tester.ensureVisible(find.text('Tinfoil'));
      await tester.tap(find.text('Tinfoil'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Open Tinfoil on your Switch'), findsOneWidget);

      // Tap Done to dismiss
      await tester.ensureVisible(find.text('DONE'));
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      expect(find.text('WIRELESS CONSOLE INSTALLER'), findsNothing);
    });

    testWidgets(
        'Displays direct install URL for target file and copies to clipboard',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      // Register an NSP file
      service.registerNsp('SuperMario.nsp', Uint8List.fromList([1, 2, 3]));

      await tester
          .pumpWidget(buildTestDialog(targetFilename: 'SuperMario.nsp'));

      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pumpAndSettle();

      expect(find.textContaining('SuperMario.nsp'), findsAtLeastNWidgets(1));

      // Tap Copy URL button
      await tester.ensureVisible(find.text('COPY URL'));
      await tester.tap(find.text('COPY URL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('COPIED'), findsOneWidget);

      // Close dialog & pump out lingering timers
      await tester.ensureVisible(find.text('DONE'));
      await tester.tap(find.text('DONE'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
