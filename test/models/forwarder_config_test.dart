// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

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
  });
}
