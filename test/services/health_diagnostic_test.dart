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
      KeysService.setForceFallback(true);
      KeysService.clearTestFallback();
    });

    tearDown(() {
      KeysService.setForceFallback(false);
      KeysService.clearTestFallback();
    });

    test('Runs health check when keys missing', () async {
      final report = await HealthDiagnosticService.runDiagnostic();

      expect(report.keysReady, isFalse);
      expect(report.issues, isNotEmpty);
    });

    test('Runs health check when keys ready', () async {
      await KeysService.saveRawKeys('''
header_key = 11223344556677889900aabbccddeeff
sd_seed = aabbccddeeff00112233445566778899
titlekdk_00 = 00112233445566778899aabbccddeeff
key_area_key_application_00 = 1234567890abcdef1234567890abcdef
''');

      final report = await HealthDiagnosticService.runDiagnostic();

      expect(report.keysReady, isTrue);
      expect(report.headerKeyPresent, isTrue);
      expect(report.sdSeedPresent, isTrue);
      expect(report.titleKdkPresent, isTrue);
      expect(report.issues, isEmpty);
    });

    test('Reports missing titlekdk_00', () async {
      await KeysService.saveRawKeys('''
header_key = 11223344556677889900aabbccddeeff
sd_seed = aabbccddeeff00112233445566778899
''');

      final report = await HealthDiagnosticService.runDiagnostic();

      expect(report.keysReady, isFalse);
      expect(report.titleKdkPresent, isFalse);
      expect(report.issues, contains('titlekdk_00 is missing from prod.keys.'));
    });
  });
}
