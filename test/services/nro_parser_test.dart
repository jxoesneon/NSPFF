// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/nro_parser.dart';

void main() {
  group('NroParser Unit Tests', () {
    test('Returns null for small or empty byte arrays', () {
      expect(NroParser.parseNro(Uint8List(0)), isNull);
      expect(NroParser.parseNro(Uint8List(0x20)), isNull);
    });

    test('Returns null for missing NRO0 magic header', () {
      final bytes = Uint8List(0x100);
      expect(NroParser.parseNro(bytes), isNull);
    });

    test('Returns default NroMetadata if ASET asset header is missing', () {
      final bytes = Uint8List(0x100);
      final view = ByteData.sublistView(bytes);

      // Write 'NRO0' magic at 0x10
      bytes[0x10] = 0x4E; // N
      bytes[0x11] = 0x52; // R
      bytes[0x12] = 0x4F; // O
      bytes[0x13] = 0x30; // 0

      view.setUint32(0x18, 0x80, Endian.little); // NRO size

      final meta = NroParser.parseNro(bytes);
      expect(meta, isNull); // size larger than byte array length
    });

    test('Parses full NRO binary with ASET asset block and NACP metadata', () {
      const int nroHeaderSize = 0x80;
      const int iconSize = 0x40;
      const int nacpSize = 0x4000;

      const int totalSize = nroHeaderSize + 0x38 + iconSize + nacpSize;
      final bytes = Uint8List(totalSize);
      final view = ByteData.sublistView(bytes);

      // Write NRO0 Magic at 0x10
      bytes[0x10] = 0x4E; // N
      bytes[0x11] = 0x52; // R
      bytes[0x12] = 0x4F; // O
      bytes[0x13] = 0x30; // 0
      view.setUint32(0x18, nroHeaderSize, Endian.little);

      // Write ASET Header at nroHeaderSize (0x80)
      bytes[0x80] = 0x41; // A
      bytes[0x81] = 0x53; // S
      bytes[0x82] = 0x45; // E
      bytes[0x83] = 0x54; // T

      // Icon offset & size (offset relative to ASET header = 0x38)
      view.setUint64(0x88, 0x38, Endian.little);
      view.setUint64(0x90, iconSize, Endian.little);

      // NACP offset & size (offset relative to ASET header = 0x38 + iconSize)
      const int nacpRelOffset = 0x38 + iconSize;
      view.setUint64(0x98, nacpRelOffset, Endian.little);
      view.setUint64(0xA0, nacpSize, Endian.little);

      // Populate NACP data (Language 0 title & author, version at 0x3060)
      const int nacpAbsStart = 0x80 + nacpRelOffset;

      final titleBytes = const Utf8Encoder().convert('Custom NRO App');
      final authorBytes = const Utf8Encoder().convert('Custom NRO Dev');
      final verBytes = const Utf8Encoder().convert('1.5.0');

      bytes.setRange(
          nacpAbsStart, nacpAbsStart + titleBytes.length, titleBytes);
      bytes.setRange(nacpAbsStart + 0x200,
          nacpAbsStart + 0x200 + authorBytes.length, authorBytes);
      bytes.setRange(nacpAbsStart + 0x3060,
          nacpAbsStart + 0x3060 + verBytes.length, verBytes);

      final meta = NroParser.parseNro(bytes);

      expect(meta, isNotNull);
      expect(meta!.title, equals('Custom NRO App'));
      expect(meta.author, equals('Custom NRO Dev'));
      expect(meta.version, equals('1.5.0'));
      expect(meta.iconBytes, isNotNull);
      expect(meta.iconBytes!.length, equals(iconSize));
    });
  });
}
