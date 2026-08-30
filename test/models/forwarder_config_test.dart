// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/models/retroarch_core.dart';

void main() {
  group('ForwarderConfig Unit Tests', () {
    test('Constructs default ForwarderConfig correctly', () {
      final config = ForwarderConfig(
        id: '0500000000000001',
        title: 'Test Game',
        publisher: 'Test Dev',
        nroPath: '/switch/game.nro',
      );

      expect(config.id, equals('0500000000000001'));
      expect(config.title, equals('Test Game'));
      expect(config.publisher, equals('Test Dev'));
      expect(config.version, equals('1.0.0'));
      expect(config.nroPath, equals('/switch/game.nro'));
      expect(config.isRetroArch, isFalse);
      expect(config.startupUserAccount, isTrue);
      expect(config.screenshot, isTrue);
      expect(config.videoCapture, isTrue);
      expect(config.enableSvcDebug, isFalse);
      expect(config.logoType, equals(LogoType.nintendo));
    });

    test('Serializes to and from JSON cleanly', () {
      final core = RetroArchCore.builtInCores.first;
      final config = ForwarderConfig(
        id: '050000000000ABCD',
        title: 'Retro Game',
        publisher: 'Retro Publisher',
        version: '2.0.0',
        nroPath: core.defaultPath,
        romPath: '/roms/snes/game.sfc',
        isRetroArch: true,
        selectedCore: core,
        startupUserAccount: false,
        screenshot: false,
        videoCapture: true,
        enableSvcDebug: true,
        logoType: LogoType.licensedByNintendo,
      );

      final json = config.toJson();
      expect(json['id'], equals('050000000000ABCD'));
      expect(json['title'], equals('Retro Game'));
      expect(json['isRetroArch'], isTrue);
      expect(json['coreId'], equals(core.id));
      expect(json['logoType'], equals(1));

      final restored = ForwarderConfig.fromJson(json);
      expect(restored.id, equals(config.id));
      expect(restored.title, equals(config.title));
      expect(restored.publisher, equals(config.publisher));
      expect(restored.version, equals(config.version));
      expect(restored.isRetroArch, isTrue);
      expect(restored.selectedCore?.id, equals(core.id));
      expect(restored.startupUserAccount, isFalse);
      expect(restored.screenshot, isFalse);
      expect(restored.videoCapture, isTrue);
      expect(restored.enableSvcDebug, isTrue);
      expect(restored.logoType, equals(LogoType.licensedByNintendo));
    });

    test('LogoType enum mapping properties', () {
      expect(LogoType.nintendo.value, equals(0));
      expect(LogoType.nintendo.label, equals('Nintendo'));
      expect(LogoType.licensedByNintendo.value, equals(1));
      expect(LogoType.distributedByNintendo.value, equals(2));
    });

    group('Value semantics', () {
      test('copyWith creates a new config with selected fields replaced', () {
        final core = RetroArchCore.builtInCores.first;
        final config = ForwarderConfig(
          id: '0500000000000001',
          title: 'Original',
          publisher: 'Pub',
          nroPath: '/switch/app.nro',
        );

        final updated = config.copyWith(
          title: 'Updated',
          version: '2.0.0',
          isRetroArch: true,
          selectedCore: core,
          logoType: LogoType.licensedByNintendo,
        );

        expect(updated.id, equals(config.id));
        expect(updated.title, equals('Updated'));
        expect(updated.version, equals('2.0.0'));
        expect(updated.isRetroArch, isTrue);
        expect(updated.selectedCore?.id, equals(core.id));
        expect(updated.logoType, equals(LogoType.licensedByNintendo));
      });

      test('copyWith can clear nullable fields to null', () {
        final image = Uint8List.fromList([1, 2, 3]);
        final config = ForwarderConfig(
          id: '0500000000000001',
          title: 'Game',
          publisher: 'Pub',
          nroPath: '/switch/app.nro',
          imageBytes: image,
        );

        final cleared = config.copyWith(imageBytes: null);
        expect(cleared.imageBytes, isNull);
        expect(cleared.title, equals(config.title));
      });

      test('operator == and hashCode are based on field values', () {
        final image = Uint8List.fromList([1, 2, 3, 4]);
        final core = RetroArchCore.builtInCores.first;

        final a = ForwarderConfig(
          id: '0500000000000001',
          title: 'Game',
          publisher: 'Pub',
          nroPath: '/switch/app.nro',
          isRetroArch: true,
          selectedCore: core,
          imageBytes: image,
          logoType: LogoType.licensedByNintendo,
        );

        final b = ForwarderConfig(
          id: '0500000000000001',
          title: 'Game',
          publisher: 'Pub',
          nroPath: '/switch/app.nro',
          isRetroArch: true,
          selectedCore: core,
          imageBytes: Uint8List.fromList([1, 2, 3, 4]),
          logoType: LogoType.licensedByNintendo,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));

        final c = b.copyWith(title: 'Different');
        expect(a, isNot(equals(c)));
      });

      test('Uint8List fields are compared by content, not identity', () {
        final a = ForwarderConfig(
          id: '0500000000000001',
          title: 'Game',
          publisher: 'Pub',
          nroPath: '/switch/app.nro',
          imageBytes: Uint8List.fromList([1, 2, 3]),
        );

        final b = ForwarderConfig(
          id: '0500000000000001',
          title: 'Game',
          publisher: 'Pub',
          nroPath: '/switch/app.nro',
          imageBytes: Uint8List.fromList([1, 2, 3]),
        );

        final c = ForwarderConfig(
          id: '0500000000000001',
          title: 'Game',
          publisher: 'Pub',
          nroPath: '/switch/app.nro',
          imageBytes: Uint8List.fromList([3, 2, 1]),
        );

        expect(a, equals(b));
        expect(a, isNot(equals(c)));
      });
    });
  });
}
