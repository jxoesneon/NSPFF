import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/models/prod_keys.dart';
import 'package:nspff/services/nsp_generator.dart';

String _readKeyText(String keysDir, String name) {
  final file = File('$keysDir/$name');
  return file.existsSync() ? file.readAsStringSync() : '';
}

ProdKeys _loadKeys() {
  const keysDir = String.fromEnvironment('KEYS_DIR');
  if (keysDir.isNotEmpty) {
    final prod = _readKeyText(keysDir, 'prod.keys');
    final title = _readKeyText(keysDir, 'title.keys');
    return ProdKeys.parse('$prod\n$title'.trim());
  }

  // Fallback test-only keys for offline unit testing.
  return ProdKeys.parse(
      'header_key=11223344556677889900aabbccddeeff\nsd_seed=aabbccddeeff');
}

void main() {
  test('Writes a Donut homebrew forwarder NSP', () async {
    const nroPath =
        String.fromEnvironment('NRO_PATH', defaultValue: '/switch/Donut.nro');
    const titleId =
        String.fromEnvironment('TITLE_ID', defaultValue: '0500000000000002');
    const nspName =
        String.fromEnvironment('NSP_NAME', defaultValue: 'build/Donut.nsp');

    final outputFile = File(nspName);
    await outputFile.parent.create(recursive: true);

    final config = ForwarderConfig(
      id: titleId,
      title: 'Donut',
      publisher: 'Ted Was Here',
      version: '1.0.0',
      nroPath: nroPath,
    );

    final result =
        await NspGenerator.generateNsp(config: config, keys: _loadKeys());
    await outputFile.writeAsBytes(result.nspBytes);

    expect(outputFile.existsSync(), isTrue);
    expect(outputFile.lengthSync(), greaterThan(0x1000));
  });
}
