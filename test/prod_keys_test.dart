import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/prod_keys.dart';

void main() {
  group('ProdKeys Model Tests', () {
    test('Parses valid prod.keys correctly', () {
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

    test('Detects missing recommended keys', () {
      const incompleteKeys = '''
header_key = 11223344556677889900aabbccddeeff
''';

      final keys = ProdKeys.parse(incompleteKeys);

      expect(keys.isValid, isTrue); // has header key
      expect(keys.hasHeaderKey, isTrue);
      expect(keys.hasSdSeed, isFalse);
      expect(keys.missingRecommendedKeys, contains('sd_seed'));
    });
  });
}
