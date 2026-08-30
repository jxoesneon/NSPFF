// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/title_id.dart';
import 'package:nspff/services/title_id_registry_service.dart';

void main() {
  group('TitleId.generateRandomId', () {
    setUp(() {
      TitleIdRegistryService.resetCache();
    });

    tearDown(() {
      TitleIdRegistryService.resetCache();
    });

    test('Generates 16-character uppercase hex strings in the 05 range', () {
      final ids = List.generate(20, (_) => TitleId.generateRandomId());
      final hexRegex = RegExp(r'^[0-9A-F]{16}$');

      for (final id in ids) {
        expect(id.length, equals(16));
        expect(hexRegex.hasMatch(id), isTrue,
            reason: '$id is not valid 16-hex');
        expect(id.startsWith('05'), isTrue,
            reason: '$id is not in the homebrew 05 range');
      }
    });

    test('Generated IDs are unique with high probability', () {
      final ids = List.generate(100, (_) => TitleId.generateRandomId());
      final unique = ids.toSet();
      expect(unique.length, equals(ids.length));
    });

    test('Avoids collisions with registered Title IDs', () {
      const registeredId = '0500000000000001';
      TitleIdRegistryService.setRegisteredCache([registeredId]);

      final ids = List.generate(50, (_) => TitleId.generateRandomId());
      for (final id in ids) {
        expect(id, isNot(equals(registeredId)));
      }
    });

    test('Top-level generateRandomTitleId delegates to TitleId', () {
      final id = generateRandomTitleId();
      expect(id.length, equals(16));
      expect(id.startsWith('05'), isTrue);
    });
  });
}
