// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/models/prod_keys.dart';
import 'package:nspff/services/nacp_builder.dart';
import 'package:nspff/services/nsp_generator.dart';

void main() {
  group('Performance & Binary Throughput Benchmark Tests', () {
    test('Measures NacpBuilder throughput for 1,000 iterations', () {
      final config = ForwarderConfig(
        id: '0500000000000001',
        title: 'Benchmark Title',
        publisher: 'Benchmark Dev',
        nroPath: '/switch/bench.nro',
      );

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        NacpBuilder.buildNacp(config);
      }
      stopwatch.stop();

      // 1,000 NACP payload generations should take less than 1,000 ms (1ms per payload)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('Measures ProdKeys parser performance for 1,000 iterations', () {
      const keysText = '''
header_key = 11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff
sd_seed = aabbccddeeff00112233445566778899
titlekdk_00 = 00112233445566778899aabbccddeeff
key_area_key_application_00 = 1234567890abcdef1234567890abcdef
''';

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        ProdKeys.parse(keysText);
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('Measures NspGenerator container build execution time', () async {
      final config = ForwarderConfig(
        id: '0500000000000001',
        title: 'Performance Test Game',
        publisher: 'Nintendo',
        nroPath: '/retroarch/cores/snes9x_libretro_libswitch.nro',
        romPath: '/roms/snes/game.sfc',
        isRetroArch: true,
      );
      final keys = ProdKeys.parse('header_key=1234\nsd_seed=5678');

      final stopwatch = Stopwatch()..start();
      final result = await NspGenerator.generateNsp(config: config, keys: keys);
      stopwatch.stop();

      expect(result.nspBytes.length, greaterThan(0));
      // Full container creation & image encode under 2000ms on mobile CPU
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });
}
