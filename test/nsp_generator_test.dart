import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/models/prod_keys.dart';
import 'package:nspff/services/nsp_generator.dart';

void main() {
  group('NspGenerator Tests', () {
    test('Generates valid PFS0 NSP container', () async {
      final config = ForwarderConfig(
        id: '0500000000000001',
        title: 'Super Mario World',
        publisher: 'Nintendo',
        version: '1.0.0',
        nroPath: '/retroarch/cores/snes9x_libretro_libswitch.nro',
        romPath: '/roms/snes/smw.sfc',
        isRetroArch: true,
      );

      final keys = ProdKeys.parse('header_key=11223344556677889900aabbccddeeff\nsd_seed=aabbccddeeff');

      final result = await NspGenerator.generateNsp(config: config, keys: keys);

      expect(result.titleId, equals('0500000000000001'));
      expect(result.filename, contains('Super Mario World'));
      expect(result.nspBytes.length, greaterThan(0x800));

      // Verify PFS0 Magic
      final magic = String.fromCharCodes(result.nspBytes.sublist(0, 4));
      expect(magic, equals('PFS0'));
    });
  });
}
