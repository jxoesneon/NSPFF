// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/title_id_registry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TitleIdRegistryService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Registers Title ID and detects collisions', () async {
      const id = '0500000000000001';

      expect(await TitleIdRegistryService.isTitleIdRegistered(id), isFalse);

      await TitleIdRegistryService.registerTitleId(id, 'Game Title');

      expect(await TitleIdRegistryService.isTitleIdRegistered(id), isTrue);
      expect(await TitleIdRegistryService.getRegisteredTitleIds(),
          contains('0500000000000001'));
    });

    test('Clears Title ID registry cleanly', () async {
      await TitleIdRegistryService.registerTitleId('050000000000ABCD', 'Game');
      await TitleIdRegistryService.clearRegistry();

      expect(await TitleIdRegistryService.getRegisteredTitleIds(), isEmpty);
    });
  });
}
