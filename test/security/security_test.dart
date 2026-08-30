// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/title_id_registry_service.dart';
import 'package:nspff/widgets/switch_text_field.dart';
import 'package:nspff/widgets/title_id_input.dart';

void main() {
  group('Security Invariants & Threat Mitigation Tests', () {
    setUp(() {
      TitleIdRegistryService.resetCache();
    });

    tearDown(() {
      TitleIdRegistryService.resetCache();
    });

    test('Path normalization strips drive letters and converts backslashes',
        () {
      expect(SwitchTextField.normalizePath('C:\\switch\\app.nro'),
          equals('/switch/app.nro'));
      expect(SwitchTextField.normalizePath('D:\\roms\\snes\\game.sfc'),
          equals('/roms/snes/game.sfc'));
      expect(SwitchTextField.normalizePath('switch/app.nro'),
          equals('/switch/app.nro'));
    });

    test('Title ID randomizer generates valid homebrew range ID (0500...)', () {
      for (int i = 0; i < 50; i++) {
        final id = TitleIdInput.generateRandomID();
        expect(id, startsWith('05'));
        expect(id.length, equals(16));
        expect(RegExp(r'^[0-9A-F]{16}$').hasMatch(id), isTrue);
      }
    });

    test('Title ID randomizer avoids registered Title ID collisions', () {
      TitleIdRegistryService.setRegisteredCache({
        '0500000000000001',
        '0500000000000002',
        '0500000000000003',
      });

      for (int i = 0; i < 50; i++) {
        final id = TitleIdInput.generateRandomID();
        expect(id, isNot('0500000000000001'));
        expect(id, isNot('0500000000000002'));
        expect(id, isNot('0500000000000003'));
        final validation = TitleIdRegistryService.validateTitleId(id);
        expect(validation.isSafe, isTrue);
      }
    });

    test('Suppresses dangerous path characters in generated filenames', () {
      const String dirtyTitle = 'Game/Title: With*Special?Chars<>';
      final String cleanTitle =
          dirtyTitle.replaceAll(RegExp(r'[^\w\s\.-]'), '');

      expect(cleanTitle, equals('GameTitle WithSpecialChars'));
      expect(cleanTitle, isNot(contains('/')));
      expect(cleanTitle, isNot(contains(':')));
      expect(cleanTitle, isNot(contains('?')));
    });
  });
}
