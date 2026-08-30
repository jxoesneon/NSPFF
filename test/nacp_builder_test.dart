import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/services/nacp_builder.dart';

void main() {
  group('NacpBuilder Tests', () {
    test('Builds valid 0x4000 byte NACP binary buffer', () {
      final config = ForwarderConfig(
        id: '0500000000000001',
        title: 'Test App',
        publisher: 'Test Publisher',
        version: '1.2.3',
        nroPath: '/switch/test.nro',
        startupUserAccount: true,
        screenshot: false,
        videoCapture: true,
        enableSvcDebug: true,
        logoType: LogoType.licensedByNintendo,
      );

      final nacp = NacpBuilder.buildNacp(config);

      expect(nacp.length, equals(0x4000));
      expect(nacp[0x3025], equals(1)); // startupUserAccount
      expect(nacp[0x3034], equals(1)); // screenshot disabled
      expect(nacp[0x3035], equals(1)); // videoCapture enabled
      expect(nacp[0x30F0], equals(1)); // LogoType licensedByNintendo
    });

    test('Does not repurpose DataLossConfirmation for enableSvcDebug', () {
      final config = ForwarderConfig(
        id: '0500000000000001',
        title: 'Test App',
        publisher: 'Test Publisher',
        version: '1.2.3',
        nroPath: '/switch/test.nro',
        enableSvcDebug: true,
      );

      final nacp = NacpBuilder.buildNacp(config);

      // NACP offset 0x3036 is DataLossConfirmation, not an SVC debug flag.
      // It must remain at its default (0) regardless of the UI toggle.
      expect(nacp[0x3036], equals(0));
    });

    test('Handles Little-Endian 64-bit Title ID parsing safely', () {
      final config = ForwarderConfig(
        id: '050000000000ABC0',
        title: 'Title ID Test',
        publisher: 'Dev',
        nroPath: '/switch/app.nro',
      );

      final nacp = NacpBuilder.buildNacp(config);

      // Verify Little-Endian bytes at 0x3038: 0xC0, 0xAB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05
      expect(nacp[0x3038], equals(0xC0));
      expect(nacp[0x3039], equals(0xAB));
      expect(nacp[0x303F], equals(0x05));
    });
  });
}
