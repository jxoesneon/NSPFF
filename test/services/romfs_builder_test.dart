// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/romfs_builder.dart';

void main() {
  group('RomfsBuilder Binary Specification & Integrity Tests', () {
    test('Calculates valid RomFS path hashes deterministically', () {
      final rootHash = RomfsBuilder.calcPathHash(0, []);
      expect(rootHash, equals(123456789 & 0xFFFFFFFF));

      final testHash =
          RomfsBuilder.calcPathHash(0, utf8.encode('control.nacp'));
      expect(testHash, isNot(equals(0)));
      expect(testHash, isA<int>());
    });

    test('Calculates prime/odd hash table bucket counts', () {
      expect(RomfsBuilder.getHashTableCount(0), equals(3));
      expect(RomfsBuilder.getHashTableCount(1), equals(3));
      expect(RomfsBuilder.getHashTableCount(2), equals(3));
      expect(RomfsBuilder.getHashTableCount(4), equals(5));
      expect(RomfsBuilder.getHashTableCount(10), equals(11));
      expect(RomfsBuilder.getHashTableCount(20), equals(23));
    });

    test('Builds compliant RomFS header and data offsets', () {
      final sampleData1 =
          Uint8List.fromList(utf8.encode('NSPFF RomFS Test Content 1'));
      final sampleData2 = Uint8List.fromList(
          utf8.encode('NSPFF RomFS Test Content 2 - Icon Data'));

      final romfs = RomfsBuilder.build({
        'test1.txt': sampleData1,
        'subdir/test2.bin': sampleData2,
      });

      expect(romfs.length, greaterThan(0x200));

      final view = ByteData.sublistView(romfs);
      final headerSize = view.getUint64(0x00, Endian.little);
      final dirHashOfs = view.getUint64(0x08, Endian.little);
      final dirHashSize = view.getUint64(0x10, Endian.little);
      final dirTableOfs = view.getUint64(0x18, Endian.little);
      final dirTableSize = view.getUint64(0x20, Endian.little);
      final fileHashOfs = view.getUint64(0x28, Endian.little);
      final fileHashSize = view.getUint64(0x30, Endian.little);
      final fileTableOfs = view.getUint64(0x38, Endian.little);
      final fileTableSize = view.getUint64(0x40, Endian.little);
      final fileDataOfs = view.getUint64(0x48, Endian.little);

      expect(headerSize, equals(0x50));
      expect(fileDataOfs, equals(0x200));
      expect(dirHashOfs, greaterThanOrEqualTo(0x200));
      expect(dirTableOfs, equals(dirHashOfs + dirHashSize));
      expect(fileHashOfs, equals(dirTableOfs + dirTableSize));
      expect(fileTableOfs, equals(fileHashOfs + fileHashSize));
      expect(romfs.length, equals(fileTableOfs + fileTableSize));

      // Root directory entry check at dirTableOfs
      final rootParent = view.getUint32(dirTableOfs + 0x00, Endian.little);
      final rootNameLen = view.getUint32(dirTableOfs + 0x14, Endian.little);
      expect(rootParent, equals(0));
      expect(rootNameLen, equals(0)); // Root dir name is empty
    });

    test('buildControlRomfs embeds control.nacp and icon_AmericanEnglish.dat',
        () {
      final nacpBytes = Uint8List(0x4000);
      nacpBytes[0] = 0x41; // 'A'
      nacpBytes[0x4000 - 1] = 0x5A; // 'Z'

      final iconBytes = Uint8List(512);
      for (int i = 0; i < 512; i++) {
        iconBytes[i] = i % 256;
      }

      final romfs = RomfsBuilder.buildControlRomfs(
        nacpBytes: nacpBytes,
        iconBytes: iconBytes,
      );

      final view = ByteData.sublistView(romfs);
      final fileTableOfs = view.getUint64(0x38, Endian.little);
      final fileTableSize = view.getUint64(0x40, Endian.little);

      // Verify file entries inside fileTable
      int foundFiles = 0;
      int cursor = fileTableOfs;
      while (cursor < fileTableOfs + fileTableSize) {
        final dataOfs = view.getUint64(cursor + 0x08, Endian.little);
        final dataSize = view.getUint64(cursor + 0x10, Endian.little);
        final nameLen = view.getUint32(cursor + 0x1C, Endian.little);
        final name =
            utf8.decode(romfs.sublist(cursor + 0x20, cursor + 0x20 + nameLen));

        final extractedBytes =
            romfs.sublist(0x200 + dataOfs, 0x200 + dataOfs + dataSize);

        if (name == 'control.nacp') {
          foundFiles++;
          expect(dataSize, equals(0x4000));
          expect(extractedBytes, equals(nacpBytes));
        } else if (name == 'icon_AmericanEnglish.dat') {
          foundFiles++;
          expect(dataSize, equals(512));
          expect(extractedBytes, equals(iconBytes));
        }

        final alignedLen = (nameLen + 3) & ~3;
        cursor += 0x20 + alignedLen;
      }

      expect(foundFiles, equals(2));
    });

    test('buildProgramRomfs formats sdmc paths and arguments correctly', () {
      final romfs = RomfsBuilder.buildProgramRomfs(
        nroPath: '/switch/cores/snes9x_libretro.nro',
        romPath: '/roms/snes/Super Mario World.sfc',
      );

      final view = ByteData.sublistView(romfs);
      final fileTableOfs = view.getUint64(0x38, Endian.little);
      final fileTableSize = view.getUint64(0x40, Endian.little);

      String? nextNroPathContent;
      String? nextArgvContent;

      int cursor = fileTableOfs;
      while (cursor < fileTableOfs + fileTableSize) {
        final dataOfs = view.getUint64(cursor + 0x08, Endian.little);
        final dataSize = view.getUint64(cursor + 0x10, Endian.little);
        final nameLen = view.getUint32(cursor + 0x1C, Endian.little);
        final name =
            utf8.decode(romfs.sublist(cursor + 0x20, cursor + 0x20 + nameLen));
        final content = utf8
            .decode(romfs.sublist(0x200 + dataOfs, 0x200 + dataOfs + dataSize));

        if (name == 'nextNroPath') {
          nextNroPathContent = content;
        } else if (name == 'nextArgv') {
          nextArgvContent = content;
        }

        final alignedLen = (nameLen + 3) & ~3;
        cursor += 0x20 + alignedLen;
      }

      expect(
          nextNroPathContent, equals('sdmc:/switch/cores/snes9x_libretro.nro'));
      expect(
        nextArgvContent,
        equals(
            'sdmc:/switch/cores/snes9x_libretro.nro "sdmc:/roms/snes/Super Mario World.sfc"'),
      );
    });
  });
}
