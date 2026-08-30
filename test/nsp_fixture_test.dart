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
  // Prefer full key material from environment variables (e.g. GitHub Secrets).
  final prod = Platform.environment['NSPFF_PROD_KEYS'] ?? '';
  final title = Platform.environment['NSPFF_TITLE_KEYS'] ?? '';
  if (prod.isNotEmpty || title.isNotEmpty) {
    return ProdKeys.parse('$prod\n$title'.trim());
  }

  // Next, read key files from a directory (local test setup).
  const keysDir = String.fromEnvironment('KEYS_DIR');
  if (keysDir.isNotEmpty) {
    final prodFile = _readKeyText(keysDir, 'prod.keys');
    final titleFile = _readKeyText(keysDir, 'title.keys');
    return ProdKeys.parse('$prodFile\n$titleFile'.trim());
  }

  // Fallback test-only keys for offline unit testing.
  return ProdKeys.parse(
      'header_key=11223344556677889900aabbccddeeff\nsd_seed=aabbccddeeff');
}

void main() {
  test('Writes a homebrew forwarder NSP fixture', () async {
    const nroPath =
        String.fromEnvironment('NRO_PATH', defaultValue: '/switch/test.nro');
    const titleId =
        String.fromEnvironment('TITLE_ID', defaultValue: '0500000000000000');
    const nspName =
        String.fromEnvironment('NSP_NAME', defaultValue: 'build/forwarder.nsp');

    final outputFile = File(nspName);
    await outputFile.parent.create(recursive: true);

    final config = ForwarderConfig(
      id: titleId,
      title: 'Forwarder',
      publisher: 'Homebrew',
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
