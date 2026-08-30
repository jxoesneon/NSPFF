// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/services/forwarder_stub_template.dart';
import 'package:nspff/services/nca_builder.dart';

void main() {
  final sampleConfig = ForwarderConfig(
    title: 'Super Mario World',
    id: '0500000000000001',
    publisher: 'Nintendo',
    version: '1.0.0',
    nroPath: '/switch/cores/snes9x_libretro.nro',
    romPath: '/roms/snes/smw.sfc',
    isRetroArch: true,
  );

  group('ForwarderStubTemplate Verification Tests', () {
    test('Embedded ARM64 executable has valid NSO0 header magic', () {
      final mainBinary = ForwarderStubTemplate.getMainBinary();
      expect(mainBinary.length, greaterThan(50000));
      // NSO0 Magic at 0x00: 'NSO0' (0x4E, 0x53, 0x4F, 0x30)
      expect(mainBinary.sublist(0, 4), equals([0x4E, 0x53, 0x4F, 0x30]));
    });

    test('Patched NPDM contains correct 64-bit Title ID at ACID and ACI0', () {
      final npdm = ForwarderStubTemplate.getPatchedNpdm('0500000000000001');
      expect(npdm.length, equals(1016));
      // META Magic at 0x00
      expect(npdm.sublist(0, 4), equals(utf8.encode('META')));

      final view = ByteData.sublistView(npdm);
      // ACID Title ID Range Min (offset 0x290) & Max (offset 0x298)
      final acidMin = view.getUint64(0x290, Endian.little);
      final acidMax = view.getUint64(0x298, Endian.little);
      final expectedTid = BigInt.parse('0500000000000001', radix: 16).toInt();

      expect(acidMin, equals(expectedTid));
      expect(acidMax, equals(expectedTid));

      // ACI0 Title ID (offset 0x350)
      final aci0Tid = view.getUint64(0x350, Endian.little);
      expect(aci0Tid, equals(expectedTid));
    });

    test('buildExeFs generates valid PFS0 container with main and main.npdm',
        () {
      final exefs = ForwarderStubTemplate.buildExeFs(sampleConfig);
      expect(exefs.sublist(0, 4), equals(utf8.encode('PFS0')));

      final view = ByteData.sublistView(exefs);
      final fileCount = view.getUint32(0x04, Endian.little);
      expect(fileCount, equals(2)); // main and main.npdm
    });
  });

  group('NcaBuilder Binary Specification & Integrity Tests', () {
    test(
        'buildControlNca generates valid NCA3 container with RomFS IVFC section',
        () {
      final nacpBytes = Uint8List(0x4000);
      final iconBytes = Uint8List(512);

      final controlNca = NcaBuilder.buildControlNca(
        config: sampleConfig,
        nacpBytes: nacpBytes,
        iconBytes: iconBytes,
      );

      final bytes = controlNca.bytes;
      expect(bytes.length, greaterThan(0xC00));

      final view = ByteData.sublistView(bytes);

      // Magic 'NCA3' at 0x200
      expect(bytes.sublist(0x200, 0x204), equals([0x4E, 0x43, 0x41, 0x33]));

      // Distribution Type = 0 (Download)
      expect(bytes[0x204], equals(0));

      // Content Type = 2 (Control)
      expect(bytes[0x205], equals(NcaBuilder.contentTypeControl));

      // Content Size at 0x208
      final contentSize = view.getUint64(0x208, Endian.little);
      expect(contentSize, equals(bytes.length));

      // Section 0 Entry at 0x240: media start = 6 (0xC00 / 0x200)
      final mediaStart = view.getUint32(0x240, Endian.little);
      final mediaEnd = view.getUint32(0x244, Endian.little);
      expect(mediaStart, equals(6));
      expect(mediaEnd, equals(bytes.length ~/ 0x200));

      // Section 0 Hash at 0x280 matches SHA-256 of FsHeader 0 (0x400..0x600)
      final fsHeader0 = bytes.sublist(0x400, 0x600);
      final expectedFsHash = sha256.convert(fsHeader0).bytes;
      expect(bytes.sublist(0x280, 0x2A0), equals(expectedFsHash));

      // FsHeader 0 checks: IVFC RomFS superblock
      final fsView = ByteData.sublistView(fsHeader0);
      expect(fsView.getUint16(0x00, Endian.little), equals(2)); // Version 2
      expect(fsView.getUint8(0x02), equals(NcaBuilder.partitionTypeRomfs));
      expect(
          fsView.getUint8(0x04), equals(NcaBuilder.cryptTypeNone)); // Plaintext
      // IVFC magic at 0x08
      expect(fsHeader0.sublist(0x08, 0x0C), equals(utf8.encode('IVFC')));

      // IVFC level headers end at 0xA0; the signature salt (0xA0-0xC0) must
      // be zero and the master hash must live at FsHeader offset 0xC8.
      expect(fsHeader0.sublist(0xA8, 0xC8), everyElement(equals(0)));

      final masterHashAtC8 = fsHeader0.sublist(0xC8, 0xE8);
      expect(masterHashAtC8, isNot(everyElement(equals(0))));

      // The master hash must be the SHA-256 of the IVFC level 0 data. The
      // level 0 size is recorded in the first level header at offset 0x20.
      final level0Size = fsView.getUint64(0x20, Endian.little);
      final sectionData = bytes.sublist(0xC00);
      final level0Data = sectionData.sublist(0, level0Size);
      expect(masterHashAtC8, equals(sha256.convert(level0Data).bytes));

      // NcaResult fields
      expect(controlNca.filename, endsWith('.nca'));
      expect(controlNca.filename, isNot(contains('.cnmt.nca')));
      expect(controlNca.ncaIdHex.length, equals(32));
      expect(controlNca.hash, equals(sha256.convert(bytes).bytes));
    });

    test(
        'buildProgramNca generates valid NCA3 container with Section 0 ExeFS and Section 1 RomFS',
        () {
      final programNca = NcaBuilder.buildProgramNca(config: sampleConfig);
      final bytes = programNca.bytes;
      final view = ByteData.sublistView(bytes);

      // Magic 'NCA3'
      expect(bytes.sublist(0x200, 0x204), equals([0x4E, 0x43, 0x41, 0x33]));

      // Content Type = 0 (Program)
      expect(bytes[0x205], equals(NcaBuilder.contentTypeProgram));

      // Section 0 Entry at 0x240 (ExeFS)
      final sec0Start = view.getUint32(0x240, Endian.little);
      final sec0End = view.getUint32(0x244, Endian.little);
      expect(sec0Start, equals(6));
      expect(sec0End, greaterThan(sec0Start));

      // Section 1 Entry at 0x250 (Program RomFS)
      final sec1Start = view.getUint32(0x250, Endian.little);
      final sec1End = view.getUint32(0x254, Endian.little);
      expect(sec1Start, equals(sec0End));
      expect(sec1End, equals(bytes.length ~/ 0x200));

      // Section hashes match respective FsHeaders
      final fsHeader0 = bytes.sublist(0x400, 0x600);
      final fsHeader1 = bytes.sublist(0x600, 0x800);
      expect(
          bytes.sublist(0x280, 0x2A0), equals(sha256.convert(fsHeader0).bytes));
      expect(
          bytes.sublist(0x2A0, 0x2C0), equals(sha256.convert(fsHeader1).bytes));

      // FsHeader 0 is PartitionFS / PFS0
      expect(fsHeader0[0x02], equals(NcaBuilder.partitionTypePfs0));

      // FsHeader 1 is RomFS / IVFC
      expect(fsHeader1[0x02], equals(NcaBuilder.partitionTypeRomfs));

      // Filename and NcaId
      expect(programNca.filename, endsWith('.nca'));
      expect(programNca.filename, isNot(contains('.cnmt.nca')));
      expect(programNca.ncaIdHex.length, equals(32));
    });

    test(
        'buildCnmtData and buildMetaNca create compliant Content Meta and Meta NCA',
        () {
      final nacpBytes = Uint8List(0x4000);
      final iconBytes = Uint8List(512);

      final controlNca = NcaBuilder.buildControlNca(
        config: sampleConfig,
        nacpBytes: nacpBytes,
        iconBytes: iconBytes,
      );
      final programNca = NcaBuilder.buildProgramNca(config: sampleConfig);

      final cnmt = NcaBuilder.buildCnmtData(
        config: sampleConfig,
        programNca: programNca,
        controlNca: controlNca,
      );

      expect(cnmt.length,
          equals(0xC0)); // 0x30 header + 2 * 0x38 records + 0x20 digest
      final cnmtView = ByteData.sublistView(cnmt);

      // Title ID at 0x00
      final expectedTid = BigInt.parse('0500000000000001', radix: 16).toInt();
      expect(cnmtView.getUint64(0x00, Endian.little), equals(expectedTid));

      // ContentMetaType = 0x80 (Application)
      expect(cnmt[0x0C], equals(0x80));

      // ContentCount = 2
      expect(cnmtView.getUint16(0x10, Endian.little), equals(2));

      // Patch ID = Title ID + 0x800
      final patchId = cnmtView.getUint64(0x20, Endian.little);
      expect(patchId, equals(expectedTid + 0x800));

      // Content Record 0 (Program NCA)
      expect(cnmt.sublist(0x30, 0x50), equals(programNca.hash));
      expect(cnmt.sublist(0x50, 0x60), equals(programNca.hash.sublist(0, 16)));
      expect(cnmt[0x66], equals(NcaBuilder.ncmContentTypeProgram)); // Program

      // Content Record 1 (Control NCA)
      expect(cnmt.sublist(0x68, 0x88), equals(controlNca.hash));
      expect(cnmt.sublist(0x88, 0x98), equals(controlNca.hash.sublist(0, 16)));
      expect(cnmt[0x9E], equals(NcaBuilder.ncmContentTypeControl)); // Control

      // Digest at 0xA0
      final expectedDigest = sha256.convert(cnmt.sublist(0, 0xA0)).bytes;
      expect(cnmt.sublist(0xA0, 0xC0), equals(expectedDigest));

      // Build Meta NCA
      final metaNca =
          NcaBuilder.buildMetaNca(config: sampleConfig, cnmtBytes: cnmt);
      expect(metaNca.bytes.sublist(0x200, 0x204),
          equals([0x4E, 0x43, 0x41, 0x33]));
      expect(metaNca.bytes[0x205], equals(NcaBuilder.contentTypeMeta));
      expect(metaNca.filename, endsWith('.cnmt.nca'));
      expect(metaNca.filename, startsWith(metaNca.ncaIdHex));
    });

    test(
        'PFS0 master hash is computed over the raw hash table and uses per-section block sizes',
        () {
      final programNca = NcaBuilder.buildProgramNca(config: sampleConfig);
      final metaNca = NcaBuilder.buildMetaNca(
        config: sampleConfig,
        cnmtBytes: NcaBuilder.buildCnmtData(
          config: sampleConfig,
          programNca: programNca,
          controlNca: NcaBuilder.buildControlNca(
            config: sampleConfig,
            nacpBytes: Uint8List(0x4000),
            iconBytes: Uint8List(512),
          ),
        ),
      );

      // Program NCA section 0 (ExeFS) should use a 0x10000 hash block.
      final programBytes = programNca.bytes;
      final programFsHeader = ByteData.sublistView(
          Uint8List.fromList(programBytes.sublist(0x400, 0x600)));
      expect(
        programFsHeader.getUint32(0x28, Endian.little),
        equals(NcaBuilder.pfs0ExefsHashBlockSize),
      );

      _verifyPfs0Superblock(
        programBytes,
        programFsHeader,
      );

      // Meta NCA section 0 (CNMT PFS0) should use a 0x1000 hash block.
      final metaBytes = metaNca.bytes;
      final metaFsHeader = ByteData.sublistView(
          Uint8List.fromList(metaBytes.sublist(0x400, 0x600)));
      expect(
        metaFsHeader.getUint32(0x28, Endian.little),
        equals(NcaBuilder.pfs0MetaHashBlockSize),
      );

      _verifyPfs0Superblock(
        metaBytes,
        metaFsHeader,
      );
    });
  });
}

void _verifyPfs0Superblock(Uint8List ncaBytes, ByteData fsHeader) {
  final ncaView = ByteData.sublistView(ncaBytes);
  final mediaStart = ncaView.getUint32(0x240, Endian.little);
  final sectionOffset = mediaStart * 0x200;

  final hashTableSize = fsHeader.getUint64(0x38, Endian.little).toInt();
  final pfs0Offset = fsHeader.getUint64(0x40, Endian.little).toInt();
  final pfs0Size = fsHeader.getUint64(0x48, Endian.little).toInt();

  // The master hash must be the SHA-256 of exactly hashTableSize bytes.
  final sectionData = ncaBytes.sublist(sectionOffset);
  final rawHashTable = sectionData.sublist(0, hashTableSize);
  final masterHash = fsHeader.buffer.asUint8List().sublist(0x08, 0x28);
  expect(masterHash, equals(sha256.convert(rawHashTable).bytes));

  // The on-disk hash table must be padded to the hacPack 0x200 boundary.
  expect(pfs0Offset % NcaBuilder.pfs0PaddingSize, equals(0));
  expect(pfs0Offset, greaterThanOrEqualTo(hashTableSize));

  // The PFS0 data must start with the PFS0 magic.
  final pfs0Bytes = sectionData.sublist(pfs0Offset, pfs0Offset + pfs0Size);
  expect(pfs0Bytes.sublist(0, 4), equals(utf8.encode('PFS0')));
}
