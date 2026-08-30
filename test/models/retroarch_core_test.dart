// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/retroarch_core.dart';

void main() {
  group('RetroArchCore Unit Tests', () {
    test('Validates built-in cores list consistency', () {
      const cores = RetroArchCore.builtInCores;

      expect(cores, isNotEmpty);
      expect(cores.length, greaterThanOrEqualTo(25));

      for (var core in cores) {
        expect(core.id, isNotEmpty);
        expect(core.displayName, isNotEmpty);
        expect(core.systemName, isNotEmpty);
        expect(core.coreFilename, endsWith('.nro'));
        expect(core.defaultPath, startsWith('/retroarch/cores/'));
        expect(core.category, isNotEmpty);
      }
    });

    test('Contains key console categories', () {
      final categories =
          RetroArchCore.builtInCores.map((c) => c.category).toSet();

      expect(categories, contains('Nintendo'));
      expect(categories, contains('Sony'));
      expect(categories, contains('Sega'));
      expect(categories, contains('Arcade'));
      expect(categories, contains('SNK'));
      expect(categories, contains('Atari'));
      expect(categories, contains('PC'));
    });
  });
}
