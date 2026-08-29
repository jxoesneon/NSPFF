// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/health_diagnostic_service.dart';
import 'package:nspff/services/keys_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthDiagnosticService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Runs health check when keys missing', () async {
      final report = await HealthDiagnosticService.runDiagnostic();

      expect(report.keysReady, isFalse);
      expect(report.issues, isNotEmpty);
    });

    test('Runs health check when keys ready', () async {
      await KeysService.saveKeys('''
header_key = 11223344556677889900aabbccddeeff
sd_seed = aabbccddeeff
titlekdk_00 = 00112233
''');

      final report = await HealthDiagnosticService.runDiagnostic();

      expect(report.keysReady, isTrue);
      expect(report.headerKeyPresent, isTrue);
      expect(report.sdSeedPresent, isTrue);
      expect(report.titleKdkPresent, isTrue);
    });
  });
}
