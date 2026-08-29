// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/autodetect_inference_service.dart';

void main() {
  group('AutodetectInferenceService Unit Tests', () {
    test('Strips dump tags from ROM titles correctly', () {
      expect(AutodetectInferenceService.cleanTitle('Super Mario World (USA) (Rev 1).sfc'), equals('Super Mario World'));
      expect(AutodetectInferenceService.cleanTitle('Pokemon - Emerald Version (USA, Europe) [!].gba'), equals('Pokemon - Emerald Version'));
      expect(AutodetectInferenceService.cleanTitle('Chrono_Trigger_USA.z64'), equals('Chrono Trigger USA'));
    });

    test('Infers ROM system, core, and target SD path from extension', () {
      final snesResult = AutodetectInferenceService.inferRomDetails('/downloads/Super Mario World (USA).sfc');
      expect(snesResult.title, equals('Super Mario World'));
      expect(snesResult.core?.id, equals('snes9x'));
      expect(snesResult.romSdPath, equals('/roms/snes/Super Mario World (USA).sfc'));
      expect(snesResult.titleId, startsWith('05'));

      final gbaResult = AutodetectInferenceService.inferRomDetails('Pokemon Emerald (USA).gba');
      expect(gbaResult.title, equals('Pokemon Emerald'));
      expect(gbaResult.core?.id, equals('mgba'));
      expect(gbaResult.romSdPath, equals('/roms/gba/Pokemon Emerald (USA).gba'));
    });

    test('Infers NRO target SD path and metadata', () {
      final nroResult = AutodetectInferenceService.inferNroDetails('/downloads/hbmenu.nro');
      expect(nroResult.title, equals('hbmenu'));
      expect(nroResult.nroSdPath, equals('/switch/hbmenu.nro'));
      expect(nroResult.publisher, equals('Switch Homebrew'));
      expect(nroResult.titleId, startsWith('05'));
    });
  });
}
