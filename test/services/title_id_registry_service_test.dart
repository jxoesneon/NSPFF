// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/title_id_registry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TitleIdRegistryService & Conflict Guard Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TitleIdRegistryService.resetCache();
    });

    tearDown(() {
      TitleIdRegistryService.resetCache();
    });

    group(
        'Reserved Nintendo System Modules Range (0100000000000000 - 0100000000000045)',
        () {
      test('Detects collision on start boundary 0100000000000000', () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000000000');
        expect(result.isValid, isFalse);
        expect(result.isReservedSystem, isTrue);
        expect(result.isRetailConflict, isFalse);
        expect(result.warningMessage, contains('System Module'));
      });

      test('Detects collision on middle module 0100000000000020', () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000000020');
        expect(result.isValid, isFalse);
        expect(result.isReservedSystem, isTrue);
        expect(result.isRetailConflict, isFalse);
        expect(result.warningMessage, contains('System Module'));
      });

      test('Detects collision on end boundary 0100000000000045', () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000000045');
        expect(result.isValid, isFalse);
        expect(result.isReservedSystem, isTrue);
        expect(result.isRetailConflict, isFalse);
        expect(result.warningMessage, contains('System Module'));
      });

      test(
          'One past boundary (0100000000000046) is retail conflict, not system module',
          () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000000046');
        expect(result.isReservedSystem, isFalse);
        expect(result.isRetailConflict, isTrue);
        expect(result.isValid, isFalse);
        expect(result.warningMessage, contains('0100...'));
      });
    });

    group(
        'Reserved Nintendo System Data Range (0100000000000800 - 0100000000000830)',
        () {
      test('Detects collision on start boundary 0100000000000800', () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000000800');
        expect(result.isValid, isFalse);
        expect(result.isReservedSystem, isTrue);
        expect(result.isRetailConflict, isFalse);
        expect(result.warningMessage, contains('System Data'));
      });

      test('Detects collision on middle data archive 0100000000000815', () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000000815');
        expect(result.isValid, isFalse);
        expect(result.isReservedSystem, isTrue);
        expect(result.isRetailConflict, isFalse);
        expect(result.warningMessage, contains('System Data'));
      });

      test('Detects collision on end boundary 0100000000000830', () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000000830');
        expect(result.isValid, isFalse);
        expect(result.isReservedSystem, isTrue);
        expect(result.isRetailConflict, isFalse);
        expect(result.warningMessage, contains('System Data'));
      });

      test(
          'One before boundary (01000000000007FF) and after (0100000000000831) are retail conflicts',
          () {
        final before =
            TitleIdRegistryService.validateTitleId('01000000000007FF');
        expect(before.isReservedSystem, isFalse);
        expect(before.isRetailConflict, isTrue);
        expect(before.isValid, isFalse);

        final after =
            TitleIdRegistryService.validateTitleId('0100000000000831');
        expect(after.isReservedSystem, isFalse);
        expect(after.isRetailConflict, isTrue);
        expect(after.isValid, isFalse);
      });
    });

    group(
        'Reserved Nintendo System Applets Range (0100000000001000 - 0100000000001015)',
        () {
      test('Detects collision on start boundary 0100000000001000', () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000001000');
        expect(result.isValid, isFalse);
        expect(result.isReservedSystem, isTrue);
        expect(result.isRetailConflict, isFalse);
        expect(result.warningMessage, contains('System Applet'));
      });

      test('Detects collision on middle applet 0100000000001008', () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000001008');
        expect(result.isValid, isFalse);
        expect(result.isReservedSystem, isTrue);
        expect(result.isRetailConflict, isFalse);
        expect(result.warningMessage, contains('System Applet'));
      });

      test('Detects collision on end boundary 0100000000001015', () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000001015');
        expect(result.isValid, isFalse);
        expect(result.isReservedSystem, isTrue);
        expect(result.isRetailConflict, isFalse);
        expect(result.warningMessage, contains('System Applet'));
      });

      test('One past boundary (0100000000001016) is retail conflict', () {
        final result =
            TitleIdRegistryService.validateTitleId('0100000000001016');
        expect(result.isReservedSystem, isFalse);
        expect(result.isRetailConflict, isTrue);
        expect(result.isValid, isFalse);
      });
    });

    group('Retail Game Base Range (0100...) Conflict', () {
      test('Identifies standard retail game ID collision', () {
        // Super Smash Bros Ultimate
        final result =
            TitleIdRegistryService.validateTitleId('01006F8002326000');
        expect(result.isReservedSystem, isFalse);
        expect(result.isRetailConflict, isTrue);
        expect(result.isValid, isFalse);
        expect(result.isInHomebrewRange, isFalse);
        expect(result.isSafe, isFalse);
        expect(result.warningMessage, contains('0100...'));
      });

      test('Identifies retail game range with 0x prefix and lowercase', () {
        final result =
            TitleIdRegistryService.validateTitleId('0x0100152000022000');
        expect(result.isReservedSystem, isFalse);
        expect(result.isRetailConflict, isTrue);
        expect(result.isValid, isFalse);
        expect(result.warningMessage, contains('retail games'));
      });

      test('Explicit override can allow retail ID after clear warning', () {
        final result = TitleIdRegistryService.validateTitleId(
          '01006F8002326000',
          allowUnsafe: true,
        );
        expect(result.isRetailConflict, isTrue);
        expect(result.isValid, isTrue);
        expect(result.isInHomebrewRange, isFalse);
        expect(result.isSafe, isFalse);
        expect(result.warningMessage, isNotNull);
      });
    });

    group(
        'Valid Homebrew Forwarder Range (0x0500000000000000 - 0x05FFFFFFFFFFFFFF)',
        () {
      test('Validates start boundary 0500000000000000', () {
        final result =
            TitleIdRegistryService.validateTitleId('0500000000000000');
        expect(result.isValid, isTrue);
        expect(result.isReservedSystem, isFalse);
        expect(result.isRetailConflict, isFalse);
        expect(result.isInHomebrewRange, isTrue);
        expect(result.isSafe, isTrue);
        expect(result.warningMessage, isNull);
      });

      test('Validates typical homebrew forwarder ID 0500000000000001', () {
        final result =
            TitleIdRegistryService.validateTitleId('0500000000000001');
        expect(result.isValid, isTrue);
        expect(result.isReservedSystem, isFalse);
        expect(result.isRetailConflict, isFalse);
        expect(result.isInHomebrewRange, isTrue);
        expect(result.isSafe, isTrue);
        expect(result.warningMessage, isNull);
      });

      test('Validates end boundary 05FFFFFFFFFFFFFF', () {
        final result =
            TitleIdRegistryService.validateTitleId('05FFFFFFFFFFFFFF');
        expect(result.isValid, isTrue);
        expect(result.isReservedSystem, isFalse);
        expect(result.isRetailConflict, isFalse);
        expect(result.isInHomebrewRange, isTrue);
        expect(result.isSafe, isTrue);
        expect(result.warningMessage, isNull);
      });

      test('Handles 0x prefix and space formatting seamlessly', () {
        final result =
            TitleIdRegistryService.validateTitleId('0x05ABCD1234567890');
        expect(result.isValid, isTrue);
        expect(result.isInHomebrewRange, isTrue);
        expect(result.warningMessage, isNull);
      });
    });

    group('Outside Homebrew Forwarder Range Warnings', () {
      test('Warns when Title ID starts with 04 (e.g. 0400000000000001)', () {
        final result =
            TitleIdRegistryService.validateTitleId('0400000000000001');
        expect(result.isValid, isFalse);
        expect(result.isReservedSystem, isFalse);
        expect(result.isRetailConflict, isFalse);
        expect(result.isInHomebrewRange, isFalse);
        expect(result.isSafe, isFalse);
        expect(result.warningMessage,
            contains('outside the recommended homebrew forwarder range'));
      });

      test('Warns when Title ID starts with 06 (e.g. 0600000000000001)', () {
        final result =
            TitleIdRegistryService.validateTitleId('0600000000000001');
        expect(result.isValid, isFalse);
        expect(result.isInHomebrewRange, isFalse);
        expect(result.isSafe, isFalse);
        expect(result.warningMessage,
            contains('outside the recommended homebrew forwarder range'));
      });

      test('allowUnsafe override permits out-of-range ID with warning', () {
        final result = TitleIdRegistryService.validateTitleId(
          '0400000000000001',
          allowUnsafe: true,
        );
        expect(result.isValid, isTrue);
        expect(result.isInHomebrewRange, isFalse);
        expect(result.isSafe, isFalse);
        expect(result.warningMessage, isNotNull);
      });
    });

    group('Format Validation & Malformed Input', () {
      test('Rejects empty Title ID', () {
        final result = TitleIdRegistryService.validateTitleId('');
        expect(result.isValid, isFalse);
        expect(result.warningMessage, contains('cannot be empty'));
      });

      test('Rejects short Title ID', () {
        final result = TitleIdRegistryService.validateTitleId('0500');
        expect(result.isValid, isFalse);
        expect(result.warningMessage,
            contains('Must be exactly 16 hexadecimal characters'));
      });

      test('Rejects non-hex characters', () {
        final result =
            TitleIdRegistryService.validateTitleId('050000000000000Z');
        expect(result.isValid, isFalse);
        expect(result.warningMessage,
            contains('Must be exactly 16 hexadecimal characters'));
      });

      test('Rejects overly long Title ID', () {
        final result =
            TitleIdRegistryService.validateTitleId('050000000000000001');
        expect(result.isValid, isFalse);
      });
    });

    group('Device Registration Conflict Guard', () {
      test('Detects collision when ID is already registered', () async {
        const id = '0511223344556677';
        expect(await TitleIdRegistryService.isTitleIdRegistered(id), isFalse);

        await TitleIdRegistryService.registerTitleId(id, 'My Forwarder');
        expect(await TitleIdRegistryService.isTitleIdRegistered(id), isTrue);

        final validation = TitleIdRegistryService.validateTitleId(id);
        expect(validation.isRegistered, isTrue);
        expect(validation.warningMessage, contains('already in use'));
        expect(validation.isSafe, isFalse);
      });

      test('Async validation pulls fresh registrations', () async {
        const id = '05AABBCCDDEEFF00';
        await TitleIdRegistryService.registerTitleId(id, 'Test App');

        final validation =
            await TitleIdRegistryService.validateTitleIdAsync(id);
        expect(validation.isRegistered, isTrue);
        expect(validation.warningMessage, contains('already in use'));
      });

      test('Clearing registry removes conflict flag', () async {
        const id = '05AABBCCDDEEFF01';
        await TitleIdRegistryService.registerTitleId(id, 'Test App');
        expect(await TitleIdRegistryService.isTitleIdRegistered(id), isTrue);

        await TitleIdRegistryService.clearRegistry();
        expect(await TitleIdRegistryService.isTitleIdRegistered(id), isFalse);

        final validation = TitleIdRegistryService.validateTitleId(id);
        expect(validation.isRegistered, isFalse);
        expect(validation.isSafe, isTrue);
      });
    });

    group('registerTitleId hardening', () {
      test('Accepts safe homebrew Title ID', () async {
        const id = '05000000000000AB';
        await TitleIdRegistryService.registerTitleId(id, 'Safe Forwarder');
        expect(await TitleIdRegistryService.isTitleIdRegistered(id), isTrue);
      });

      test('Rejects reserved system Title ID', () async {
        const id = '0100000000000001';
        await expectLater(
          TitleIdRegistryService.registerTitleId(id, 'Bad'),
          throwsA(isA<ArgumentError>()),
        );
        expect(await TitleIdRegistryService.isTitleIdRegistered(id), isFalse);
      });

      test('Rejects retail Title ID', () async {
        const id = '01006F8002326000';
        await expectLater(
          TitleIdRegistryService.registerTitleId(id, 'Bad'),
          throwsA(isA<ArgumentError>()),
        );
        expect(await TitleIdRegistryService.isTitleIdRegistered(id), isFalse);
      });

      test('Rejects out-of-range Title ID', () async {
        const id = '0400000000000001';
        await expectLater(
          TitleIdRegistryService.registerTitleId(id, 'Bad'),
          throwsA(isA<ArgumentError>()),
        );
        expect(await TitleIdRegistryService.isTitleIdRegistered(id), isFalse);
      });

      test('Rejects already-registered Title ID', () async {
        const id = '05000000000000AC';
        await TitleIdRegistryService.registerTitleId(id, 'First');
        await expectLater(
          TitleIdRegistryService.registerTitleId(id, 'Second'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
