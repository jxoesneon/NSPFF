// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/pfs0_builder.dart';

void main() {
  group('Pfs0Builder Tests', () {
    test('Builds a valid PFS0 container with multiple files', () {
      final files = [
        Pfs0File(name: 'main', data: Uint8List.fromList([1, 2, 3, 4])),
        Pfs0File(name: 'main.npdm', data: Uint8List.fromList([5, 6, 7, 8, 9])),
      ];

      final pfs0 = Pfs0Builder.build(files);

      // Magic
      expect(pfs0.sublist(0, 4), equals(utf8.encode('PFS0')));

      final view = ByteData.sublistView(pfs0);
      expect(view.getUint32(0x04, Endian.little), equals(2));

      final stringTableSize = view.getUint32(0x08, Endian.little);
      expect(stringTableSize, greaterThan(0));
      expect(stringTableSize % 0x20, equals(0)); // aligned to 0x20

      // File entries
      const mainEntryOffset = 0x10;
      expect(view.getUint64(mainEntryOffset + 0x00, Endian.little), equals(0));
      expect(view.getUint64(mainEntryOffset + 0x08, Endian.little), equals(4));
      final strOffsetMain = view.getUint32(mainEntryOffset + 0x10, Endian.little);

      const npdmEntryOffset = 0x10 + 0x18;
      expect(view.getUint64(npdmEntryOffset + 0x00, Endian.little), equals(4));
      expect(view.getUint64(npdmEntryOffset + 0x08, Endian.little), equals(5));
      final strOffsetNpdm = view.getUint32(npdmEntryOffset + 0x10, Endian.little);

      // String table names
      final strTableOffset = 0x10 + files.length * 0x18;
      final strTable = pfs0.sublist(strTableOffset, strTableOffset + stringTableSize);
      final mainName = utf8.decode(strTable.sublist(strOffsetMain, strOffsetMain + 4));
      final npdmName = utf8.decode(strTable.sublist(strOffsetNpdm, strOffsetNpdm + 9));
      expect(mainName, equals('main'));
      expect(npdmName, equals('main.npdm'));

      // File data
      final headerSize = strTableOffset + stringTableSize;
      expect(pfs0.sublist(headerSize, headerSize + 4), equals([1, 2, 3, 4]));
      expect(pfs0.sublist(headerSize + 4, headerSize + 9), equals([5, 6, 7, 8, 9]));
    });

    test('buildSingle produces a valid single-file PFS0', () {
      final data = Uint8List.fromList(utf8.encode('cnmt-data'));
      final pfs0 = Pfs0Builder.buildSingle('Application_0500000000000001.cnmt', data);

      final view = ByteData.sublistView(pfs0);
      expect(pfs0.sublist(0, 4), equals(utf8.encode('PFS0')));
      expect(view.getUint32(0x04, Endian.little), equals(1));
      expect(view.getUint64(0x10, Endian.little), equals(0));
      expect(view.getUint64(0x18, Endian.little), equals(data.length));
    });

    test('Empty file list throws', () {
      expect(() => Pfs0Builder.build([]), throwsA(isA<ArgumentError>()));
    });
  });
}
