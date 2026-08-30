// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/keys_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeysService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      KeysService.setForceFallback(true);
      KeysService.clearTestFallback();
    });

    tearDown(() {
      KeysService.setForceFallback(false);
      KeysService.clearTestFallback();
    });

    test(
        'Saves raw keys text and loads parsed ProdKeys via static and instance',
        () async {
      const rawKeys = 'header_key = 11223344556677889900aabbccddeeff\n'
          'sd_seed = aabbccddeeff00112233445566778899\n'
          'titlekdk_00 = 00112233445566778899aabbccddeeff';

      final saved = await KeysService.saveRawKeys(rawKeys);
      expect(saved, isTrue);

      final keys = await KeysService.loadKeys();
      expect(keys, isNotNull);
      expect(keys!.hasHeaderKey, isTrue);
      expect(keys.hasSdSeed, isTrue);
      expect(keys.hasTitleKdk, isTrue);
      expect(keys.isValid, isTrue);

      final service = KeysService();
      await service.init();
      expect(service.hasValidKeys, isTrue);
      expect(service.currentKeys?.hasHeaderKey, isTrue);
    });

    test('Clears keys cleanly', () async {
      final service = KeysService();
      await service.saveKeys('header_key = 1234');
      expect(service.currentKeys, isNotNull);

      await service.clearKeys();
      expect(service.currentKeys, isNull);

      final keys = await KeysService.loadKeys();
      expect(keys, isNull);
    });
  });
}
