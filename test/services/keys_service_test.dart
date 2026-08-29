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
    });

    test('Saves raw keys text and loads parsed ProdKeys', () async {
      const rawKeys = 'header_key = 11223344556677889900aabbccddeeff\nsd_seed = aabbccddeeff';
      
      final saved = await KeysService.saveKeys(rawKeys);
      expect(saved, isTrue);

      final keys = await KeysService.loadKeys();
      expect(keys, isNotNull);
      expect(keys!.hasHeaderKey, isTrue);
      expect(keys.hasSdSeed, isTrue);
    });

    test('Clears keys cleanly', () async {
      await KeysService.saveKeys('header_key = 1234');
      await KeysService.clearKeys();

      final keys = await KeysService.loadKeys();
      expect(keys, isNull);
    });
  });
}
