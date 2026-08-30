// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/keys_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String sampleKeys = 'header_key = 11223344556677889900aabbccddeeff\n'
      'sd_seed = aabbccddeeff00112233445566778899\n'
      'titlekdk_00 = 00112233445566778899aabbccddeeff\n'
      'key_area_key_application_00 = 1234567890abcdef1234567890abcdef';

  group('KeysService Cryptographic Hardening (Keystore & SecureStorage)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      KeysService.clearTestFallback();
      KeysService.setForceFallback(false);
    });

    tearDown(() {
      KeysService.clearTestFallback();
      KeysService.setForceFallback(false);
    });

    test('Android options use modern defaults with resetOnError disabled', () {
      final options = KeysService.androidOptions;
      expect(options.params['encryptedSharedPreferences'], isNot('true'));
      expect(options.params['resetOnError'], equals('false'));
    });

    test('Saves raw keys to secure storage and loads correctly', () async {
      final saved = await KeysService.saveRawKeys(sampleKeys);
      expect(saved, isTrue);

      final loaded = await KeysService.loadKeys();
      expect(loaded, isNotNull);
      expect(loaded!.hasHeaderKey, isTrue);
      expect(loaded.hasSdSeed, isTrue);
      expect(loaded.hasTitleKdk, isTrue);
      expect(loaded.isValid, isTrue);
    });

    test(
        'Seamlessly migrates legacy SharedPreferences to FlutterSecureStorage on init()',
        () async {
      // Setup legacy keys in SharedPreferences
      SharedPreferences.setMockInitialValues({
        'saved_prod_keys_text': sampleKeys,
      });
      // Secure storage starts completely empty
      FlutterSecureStorage.setMockInitialValues({});

      final service = KeysService();
      expect(service.isLoaded, isFalse);
      expect(service.currentKeys, isNull);

      await service.init();

      // Service successfully loaded migrated keys
      expect(service.isLoaded, isTrue);
      expect(service.hasValidKeys, isTrue);
      expect(service.currentKeys?.hasHeaderKey, isTrue);

      // Verify legacy SharedPreferences was purged of plaintext keys
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('saved_prod_keys_text'), isNull);

      // Verify keys now persist in secure storage
      final secureKeys = await KeysService.loadKeys();
      expect(secureKeys, isNotNull);
      expect(secureKeys!.hasHeaderKey, isTrue);
    });

    test('Seamlessly migrates legacy SharedPreferences via static loadKeys()',
        () async {
      SharedPreferences.setMockInitialValues({
        'saved_prod_keys_text': sampleKeys,
      });
      FlutterSecureStorage.setMockInitialValues({});

      final keys = await KeysService.loadKeys();
      expect(keys, isNotNull);
      expect(keys!.hasHeaderKey, isTrue);
      expect(keys.hasTitleKdk, isTrue);
      expect(keys.isValid, isTrue);

      // Plaintext removed from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('saved_prod_keys_text'), isNull);
    });

    test('Clears keys from both secure storage and legacy storage', () async {
      final service = KeysService();
      await service.saveKeys(sampleKeys);
      expect(service.hasValidKeys, isTrue);

      await service.clearKeys();
      expect(service.currentKeys, isNull);
      expect(service.hasValidKeys, isFalse);

      final loaded = await KeysService.loadKeys();
      expect(loaded, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('saved_prod_keys_text'), isNull);
    });

    test('Headless fallback cleanly handles headless test environments',
        () async {
      KeysService.setForceFallback(true);

      const testContent = 'header_key = 99887766554433221100aabbccddeeff\n'
          'sd_seed = aabbccddeeff00112233445566778899\n'
          'titlekdk_00 = 00112233445566778899aabbccddeeff';
      final saved = await KeysService.saveRawKeys(testContent);
      expect(saved, isTrue);

      final loaded = await KeysService.loadKeys();
      expect(loaded, isNotNull);
      expect(loaded!.hasHeaderKey, isTrue);
      expect(loaded.hasTitleKdk, isTrue);

      final service = KeysService();
      await service.init();
      expect(service.hasValidKeys, isTrue);

      await service.clearKeys();
      expect(service.currentKeys, isNull);
      expect(await KeysService.loadKeys(), isNull);
    });

    test('saveKeys updates instance state and notifies listeners', () async {
      final service = KeysService();
      int notifyCount = 0;
      service.addListener(() {
        notifyCount++;
      });

      await service.saveKeys(sampleKeys);
      expect(service.hasValidKeys, isTrue);
      expect(notifyCount, greaterThan(0));

      await service.clearKeys();
      expect(service.hasValidKeys, isFalse);
      expect(notifyCount, greaterThan(1));
    });

    test('Does not cache decrypted prod.keys in _testFallback in production',
        () async {
      KeysService.setForceFallback(false);

      await KeysService.saveRawKeys(sampleKeys);
      // Simulate secure storage being cleared (e.g. plugin reset or eviction).
      FlutterSecureStorage.setMockInitialValues({});

      // With forceFallback off, there should be no plaintext fallback to return.
      final loaded = await KeysService.loadKeys();
      expect(loaded, isNull);

      // Even if forceFallback is toggled on after the fact, no value was cached.
      KeysService.setForceFallback(true);
      final fallbackLoaded = await KeysService.loadKeys();
      expect(fallbackLoaded, isNull);
    });
  });
}
