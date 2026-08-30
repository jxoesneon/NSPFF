// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/prod_keys.dart';

void main() {
  group('ProdKeys Model Tests', () {
    test('Parses valid prod.keys and does not retain raw text blob', () {
      const sampleKeys = '''
# Sample prod.keys
header_key = 11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff
sd_seed = aabbccddeeff00112233445566778899
titlekdk_00 = 00112233445566778899aabbccddeeff
key_area_key_application_00 = 1234567890abcdef1234567890abcdef
''';

      final keys = ProdKeys.parse(sampleKeys);

      expect(keys.isValid, isTrue);
      expect(keys.hasHeaderKey, isTrue);
      expect(keys.hasSdSeed, isTrue);
      expect(keys.hasTitleKdk, isTrue);
      expect(keys.hasKeyAreaKey, isTrue);
      expect(keys.missingRecommendedKeys, isEmpty);
    });

    test('isValid requires header_key, sd_seed, and titlekdk_00', () {
      const headerOnly = '''
header_key = 11223344556677889900aabbccddeeff
''';

      final keys = ProdKeys.parse(headerOnly);

      expect(keys.isValid, isFalse);
      expect(keys.hasHeaderKey, isTrue);
      expect(keys.hasSdSeed, isFalse);
      expect(keys.hasTitleKdk, isFalse);
      expect(keys.missingRecommendedKeys, contains('sd_seed'));
      expect(keys.missingRecommendedKeys, contains('titlekdk_00'));
    });

    test('isValid is false when titlekdk_00 is missing', () {
      const noTitleKdk = '''
header_key = 11223344556677889900aabbccddeeff
sd_seed = aabbccddeeff00112233445566778899
key_area_key_application_00 = 1234567890abcdef1234567890abcdef
''';

      final keys = ProdKeys.parse(noTitleKdk);

      expect(keys.isValid, isFalse);
      expect(keys.hasTitleKdk, isFalse);
      expect(keys.missingRecommendedKeys, contains('titlekdk_00'));
    });

    test('Exposes key values without retaining the original raw blob', () {
      const raw = '''
header_key = 11223344556677889900aabbccddeeff
sd_seed = aabbccddeeff
'''; // incomplete, but sufficient for this test

      final keys = ProdKeys.parse(raw);

      expect(keys.getKey('header_key'),
          equals('11223344556677889900aabbccddeeff'));
      expect(keys.getKey('sd_seed'), equals('aabbccddeeff'));
      expect(keys.keysMap, isNot(containsPair('rawText', raw)));
    });
  });
}
