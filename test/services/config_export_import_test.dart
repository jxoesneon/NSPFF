// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/services/config_export_import_service.dart';

void main() {
  group('ConfigExportImportService Unit Tests', () {
    test('Exports configs to JSON backup string and imports back cleanly', () {
      final config = ForwarderConfig(
        id: '0500000000000001',
        title: 'Export Test Game',
        publisher: 'Export Dev',
        nroPath: '/switch/export.nro',
      );

      final jsonStr = ConfigExportImportService.exportConfigsToJson([config]);

      expect(jsonStr, contains('NSPFF'));
      expect(jsonStr, contains('Export Test Game'));

      final importedList =
          ConfigExportImportService.importConfigsFromJson(jsonStr);

      expect(importedList, hasLength(1));
      expect(importedList.first.id, equals('0500000000000001'));
      expect(importedList.first.title, equals('Export Test Game'));
    });
  });
}
