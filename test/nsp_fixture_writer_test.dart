import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/models/prod_keys.dart';
import 'package:nspff/services/nsp_generator.dart';

void main() {
  test('Writes a synthetic smoke-test NSP to build/test.nsp', () async {
    final outputFile = File('build/test.nsp');
    await outputFile.parent.create(recursive: true);

    final config = ForwarderConfig(
      id: '0500000000000001',
      title: 'NSPFF Smoke Test',
      publisher: 'Homebrew',
      version: '1.0.0',
      nroPath: '/switch/test.nro',
      isRetroArch: false,
    );

    final keys = ProdKeys.parse(
        'header_key=11223344556677889900aabbccddeeff\nsd_seed=aabbccddeeff');

    final result = await NspGenerator.generateNsp(config: config, keys: keys);
    await outputFile.writeAsBytes(result.nspBytes);

    expect(outputFile.existsSync(), isTrue);
    expect(outputFile.lengthSync(), greaterThan(0x1000));
  });
}
