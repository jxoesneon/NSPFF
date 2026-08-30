import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

      final keys = ProdKeys.parse(
          'header_key=11223344556677889900aabbccddeeff\nsd_seed=aabbccddeeff');

      final result = await NspGenerator.generateNsp(config: config, keys: keys);

      expect(result.titleId, equals('0500000000000001'));
      expect(result.filename, contains('Super Mario World'));
      expect(result.nspBytes.length, greaterThan(0x800));

      // Verify PFS0 Magic
      final magic = String.fromCharCodes(result.nspBytes.sublist(0, 4));
      expect(magic, equals('PFS0'));

      // Verify 3 inner files with standard Nintendo naming:
      // <16-byte-hex-hash>.nca (Program)
      // <16-byte-hex-hash>.nca (Control)
      // <16-byte-hex-hash>.cnmt.nca (Meta)
      final view = ByteData.sublistView(result.nspBytes);
      final int fileCount = view.getUint32(0x04, Endian.little);
      expect(fileCount, equals(3));

      final int strTableSize = view.getUint32(0x08, Endian.little);
      final int strTableOffset = 0x10 + (fileCount * 0x18);
      final strTableBytes = result.nspBytes
          .sublist(strTableOffset, strTableOffset + strTableSize);
      final fileNames = utf8
          .decode(strTableBytes)
          .split('\x00')
          .where((s) => s.isNotEmpty)
          .toList();

      expect(fileNames.length, equals(3));
      final ncaHexRegex = RegExp(r'^[0-9a-f]{32}\.nca$');
      final cnmtHexRegex = RegExp(r'^[0-9a-f]{32}\.cnmt\.nca$');

      final regularNcas =
          fileNames.where((n) => ncaHexRegex.hasMatch(n)).toList();
      final metaNcas =
          fileNames.where((n) => cnmtHexRegex.hasMatch(n)).toList();

      expect(regularNcas.length, equals(2)); // Program and Control
      expect(metaNcas.length, equals(1)); // Meta (.cnmt.nca)
    });

    test('prepareIconJpeg compresses a large image below 0x20000 bytes', () {
      // Create a 512x512 noisy image that will definitely exceed the
      // 0x20000-byte limit at quality 90, exercising the quality loop.
      final image = img.Image(width: 512, height: 512);
      for (int y = 0; y < 512; y++) {
        for (int x = 0; x < 512; x++) {
          final r = (x * 7 + y * 13) & 0xFF;
          final g = (x * 13 + y * 7) & 0xFF;
          final b = (x * 5 + y * 11) & 0xFF;
          image.setPixelRgb(x, y, r, g, b);
        }
      }

      final icon = NspGenerator.prepareIconJpeg(image);

      expect(icon.length, lessThan(0x20000));
      expect(icon.sublist(0, 2), equals([0xFF, 0xD8])); // JPEG SOI
    });

    test('Generates a valid NSP with a large user-supplied icon', () async {
      final image = img.Image(width: 512, height: 512);
      for (int y = 0; y < 512; y++) {
        for (int x = 0; x < 512; x++) {
          final r = (x * 11 + y * 5) & 0xFF;
          final g = (x * 5 + y * 11) & 0xFF;
          final b = (x * 7 + y * 13) & 0xFF;
          image.setPixelRgb(x, y, r, g, b);
        }
      }
      final jpg = img.encodeJpg(img.copyResize(image, width: 256, height: 256), quality: 95);

      final config = ForwarderConfig(
        id: '0500000000000001',
        title: 'Icon Test',
        publisher: 'Nintendo',
        version: '1.0.0',
        nroPath: '/switch/test.nro',
        imageBytes: Uint8List.fromList(jpg),
      );

      final keys = ProdKeys.parse(
          'header_key=11223344556677889900aabbccddeeff\nsd_seed=aabbccddeeff');

      final result = await NspGenerator.generateNsp(config: config, keys: keys);

      expect(result.nspBytes.sublist(0, 4), equals([0x50, 0x46, 0x53, 0x30]));
      expect(result.nspBytes.length, greaterThan(0x1000));
    });
  });
}
