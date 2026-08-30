// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/forwarder_config.dart';
import 'forwarder_stub_template.dart';
import 'pfs0_builder.dart';
import 'romfs_builder.dart';

/// Result container for a built Nintendo Content Archive (NCA).
class NcaResult {
  /// Raw binary bytes of the entire NCA container.
  final Uint8List bytes;

  /// Full 32-byte SHA-256 hash of the NCA container.
  final Uint8List hash;

  /// Lowercase 32-character hexadecimal string representing the first 16 bytes of the hash.
  final String ncaIdHex;

  /// Standard Nintendo file name inside PFS0 (.nca or .cnmt.nca).
  final String filename;

  /// Total size of the NCA in bytes.
  final int size;

  NcaResult({
    required this.bytes,
    required this.hash,
    required this.ncaIdHex,
    required this.filename,
    required this.size,
  });
}

/// Real, specification-compliant NCA3 container builder.
///
/// Builds valid Program, Control, and Meta NCAs for Nintendo Switch PFS0 (.nsp) packages,
/// calculating accurate NCA3 headers, FsHeaders, IVFC hash hierarchies, PFS0 superblocks,
/// and CNMT metadata tables.
class NcaBuilder {
  static const int headerSize =
      0xC00; // 0x400 base header + 4 * 0x200 FsHeaders
  static const int blockSize = 0x200; // Media block size (512 bytes)
  static const int ivfcHashBlockSize = 0x4000; // 16 KB IVFC block size

  // PFS0 hash-table settings per hacPack conventions.
  static const int pfs0PaddingSize = 0x200; // hash table disk padding
  static const int pfs0ExefsHashBlockSize = 0x10000; // ExeFS (main + npdm)
  static const int pfs0MetaHashBlockSize = 0x1000; // Meta NCA CNMT PFS0

  // NCA Content Types
  static const int contentTypeProgram = 0;
  static const int contentTypeMeta = 1;
  static const int contentTypeControl = 2;

  // NCA Partition Types (written to FsHeader.fs_type)
  static const int partitionTypeRomfs = 0;
  static const int partitionTypePfs0 = 1;

  // NCA base-header content type values (not to be confused with FsHeader.fs_type).
  static const int fsTypePfs0 = 2;
  static const int fsTypeRomfs = 3;

  // NCA Encryption Types
  static const int cryptTypeNone = 1;

  // NcmContentType values used in CNMT content records.
  static const int ncmContentTypeMeta = 0;
  static const int ncmContentTypeProgram = 1;
  static const int ncmContentTypeData = 2;
  static const int ncmContentTypeControl = 3;

  /// Builds a complete Control NCA containing RomFS (NACP & Icon).
  static NcaResult buildControlNca({
    required ForwarderConfig config,
    required Uint8List nacpBytes,
    required Uint8List iconBytes,
  }) {
    final titleIdVal = parseTitleId(config.id);

    // 1. Build RomFS binary image
    final Uint8List romfsBytes = RomfsBuilder.buildControlRomfs(
      nacpBytes: nacpBytes,
      iconBytes: iconBytes,
    );

    // 2. Build IVFC level hierarchy
    final _IvfcHierarchy ivfc = _buildIvfcHierarchy(romfsBytes);

    // 3. Assemble Control NCA with single RomFS section (Section 0)
    final Uint8List ncaBytes = _buildSingleSectionNca(
      contentType: contentTypeControl,
      titleId: titleIdVal,
      partitionType: partitionTypeRomfs,
      fsType: fsTypeRomfs,
      hashType: 3, // HierarchicalIntegrityHash
      sectionData: ivfc.sectionPayload,
      setupFsSuperblock: (ByteData fsView) {
        _writeIvfcSuperblock(fsView, ivfc);
      },
    );

    final hash = Uint8List.fromList(sha256.convert(ncaBytes).bytes);
    final ncaIdHex = _bytesToHex(hash.sublist(0, 16));

    return NcaResult(
      bytes: ncaBytes,
      hash: hash,
      ncaIdHex: ncaIdHex,
      filename: '$ncaIdHex.nca',
      size: ncaBytes.length,
    );
  }

  /// Builds a complete Program NCA containing ExeFS (main & main.npdm) and Program RomFS (nextNroPath & nextArgv).
  static NcaResult buildProgramNca({
    required ForwarderConfig config,
  }) {
    final titleIdVal = parseTitleId(config.id);

    // 1. Section 0: ExeFS (PFS0 with main executable & patched main.npdm)
    final Uint8List exefsBytes = ForwarderStubTemplate.buildExeFs(config);
    final _Pfs0SectionPayload exefsSection = _buildPfs0SectionPayload(
      exefsBytes,
      hashBlockSize: pfs0ExefsHashBlockSize,
    );

    // 2. Section 1: Program RomFS (with nextNroPath & nextArgv)
    final Uint8List programRomfsBytes =
        ForwarderStubTemplate.buildProgramRomFs(config);
    final _IvfcHierarchy romfsIvfc = _buildIvfcHierarchy(programRomfsBytes);

    // 3. Assemble two-section Program NCA
    final Uint8List ncaBytes = _buildTwoSectionNca(
      contentType: contentTypeProgram,
      titleId: titleIdVal,
      // Section 0: ExeFS
      sec0PartitionType: partitionTypePfs0,
      sec0FsType: fsTypePfs0,
      sec0HashType: 2, // HierarchicalSha256Hash
      sec0Data: exefsSection.payload,
      setupSec0FsSuperblock: (ByteData fsView) {
        _writePfs0Superblock(fsView, exefsSection);
      },
      // Section 1: RomFS
      sec1PartitionType: partitionTypeRomfs,
      sec1FsType: fsTypeRomfs,
      sec1HashType: 3, // HierarchicalIntegrityHash
      sec1Data: romfsIvfc.sectionPayload,
      setupSec1FsSuperblock: (ByteData fsView) {
        _writeIvfcSuperblock(fsView, romfsIvfc);
      },
    );

    final hash = Uint8List.fromList(sha256.convert(ncaBytes).bytes);
    final ncaIdHex = _bytesToHex(hash.sublist(0, 16));

    return NcaResult(
      bytes: ncaBytes,
      hash: hash,
      ncaIdHex: ncaIdHex,
      filename: '$ncaIdHex.nca',
      size: ncaBytes.length,
    );
  }

  /// Builds Content Meta (CNMT) binary data referencing Program NCA and Control NCA.
  ///
  /// Per NcmContentType, the Program NCA is recorded as type 0x1 and the
  /// Control NCA as type 0x3.
  static Uint8List buildCnmtData({
    required ForwarderConfig config,
    required NcaResult programNca,
    required NcaResult controlNca,
  }) {
    final titleIdVal = parseTitleId(config.id);
    final int versionVal = parseVersionNumber(config.version);

    // CNMT layout:
    // 0x00..0x20: PackagedContentMetaHeader
    // 0x20..0x30: ApplicationMetaExtendedHeader
    // 0x30..0x68: Content Record 0 (Program NCA, 0x38 bytes)
    // 0x68..0xA0: Content Record 1 (Control NCA, 0x38 bytes)
    // 0xA0..0xC0: Digest (SHA-256 of 0x00..0xA0, 0x20 bytes)
    const int headerSize = 0x30;
    const int recordSize = 0x38;
    const int totalRecords = 2;
    const int digestSize = 0x20;
    const int totalCnmtSize =
        headerSize + (totalRecords * recordSize) + digestSize;

    final Uint8List buffer = Uint8List(totalCnmtSize);
    final ByteData view = ByteData.sublistView(buffer);

    // 1. PackagedContentMetaHeader
    writeUint64Le(view, 0x00, titleIdVal);
    view.setUint32(0x08, versionVal, Endian.little);
    view.setUint8(0x0C, 0x80); // ContentMetaType = Application (0x80)
    view.setUint8(0x0D, 0x00); // Platform / Reserved
    view.setUint16(0x0E, 0x10, Endian.little); // ExtendedHeaderSize = 0x10
    view.setUint16(0x10, totalRecords, Endian.little); // ContentCount = 2
    view.setUint16(0x12, 0x00, Endian.little); // ContentMetaCount = 0
    view.setUint8(0x14, 0x00); // Attributes
    // 0x15..0x18 Reserved
    view.setUint32(0x18, 0x00, Endian.little); // RequiredDownloadSystemVersion
    // 0x1C..0x20 Reserved

    // 2. ApplicationMetaExtendedHeader
    final BigInt patchId = titleIdVal + BigInt.from(0x800);
    writeUint64Le(view, 0x20, patchId);
    view.setUint32(0x28, 0x00, Endian.little); // RequiredSystemVersion
    view.setUint32(0x2C, 0x00, Endian.little); // RequiredApplicationVersion

    // 3. Content Record 0: Program NCA
    int recOffset = 0x30;
    buffer.setRange(recOffset, recOffset + 0x20, programNca.hash);
    buffer.setRange(
        recOffset + 0x20, recOffset + 0x30, programNca.hash.sublist(0, 16));
    writeUint48Le(view, recOffset + 0x30, programNca.size);
    view.setUint8(recOffset + 0x36, ncmContentTypeProgram);
    view.setUint8(recOffset + 0x37, 0x00); // IdOffset

    // 4. Content Record 1: Control NCA
    recOffset += recordSize;
    buffer.setRange(recOffset, recOffset + 0x20, controlNca.hash);
    buffer.setRange(
        recOffset + 0x20, recOffset + 0x30, controlNca.hash.sublist(0, 16));
    writeUint48Le(view, recOffset + 0x30, controlNca.size);
    view.setUint8(recOffset + 0x36, ncmContentTypeControl);
    view.setUint8(recOffset + 0x37, 0x00); // IdOffset

    // 5. Digest: SHA-256 over 0x00..0xA0
    recOffset += recordSize;
    final digest = sha256.convert(buffer.sublist(0, recOffset)).bytes;
    buffer.setRange(recOffset, recOffset + digestSize, digest);

    return buffer;
  }

  /// Builds a complete Meta NCA (.cnmt.nca) containing the CNMT metadata in a Section 0 PFS0.
  static NcaResult buildMetaNca({
    required ForwarderConfig config,
    required Uint8List cnmtBytes,
  }) {
    final titleIdVal = parseTitleId(config.id);
    final titleIdHex =
        titleIdVal.toRadixString(16).toUpperCase().padLeft(16, '0');

    // 1. Pack CNMT file into PFS0 container named 'Application_<TitleID>.cnmt'
    final String cnmtFileName = 'Application_$titleIdHex.cnmt';
    final Uint8List cnmtPfs0 = Pfs0Builder.buildSingle(cnmtFileName, cnmtBytes);
    final _Pfs0SectionPayload metaSection = _buildPfs0SectionPayload(
      cnmtPfs0,
      hashBlockSize: pfs0MetaHashBlockSize,
    );

    // 2. Assemble Meta NCA with Section 0 PFS0
    final Uint8List ncaBytes = _buildSingleSectionNca(
      contentType: contentTypeMeta,
      titleId: titleIdVal,
      partitionType: partitionTypePfs0,
      fsType: fsTypePfs0,
      hashType: 2, // HierarchicalSha256Hash
      sectionData: metaSection.payload,
      setupFsSuperblock: (ByteData fsView) {
        _writePfs0Superblock(fsView, metaSection);
      },
    );

    final hash = Uint8List.fromList(sha256.convert(ncaBytes).bytes);
    final ncaIdHex = _bytesToHex(hash.sublist(0, 16));

    return NcaResult(
      bytes: ncaBytes,
      hash: hash,
      ncaIdHex: ncaIdHex,
      filename: '$ncaIdHex.cnmt.nca',
      size: ncaBytes.length,
    );
  }

  // --- Internal Binary Assembly Helpers ---

  /// Assembles an NCA3 container with a single partition section at index 0.
  static Uint8List _buildSingleSectionNca({
    required int contentType,
    required BigInt titleId,
    required int partitionType,
    required int fsType,
    required int hashType,
    required Uint8List sectionData,
    required void Function(ByteData fsView) setupFsSuperblock,
  }) {
    // Pad section data to 0x200 block boundary
    final int secPad =
        (blockSize - (sectionData.length % blockSize)) % blockSize;
    final int secSizeAligned = sectionData.length + secPad;

    final int totalNcaSize = headerSize + secSizeAligned;
    final Uint8List ncaBuffer = Uint8List(totalNcaSize);
    final ByteData view = ByteData.sublistView(ncaBuffer);

    // 1. Base Header at 0x000 (Magic at 0x200)
    _writeBaseNcaHeader(
      view: view,
      contentType: contentType,
      titleId: titleId,
      totalSize: totalNcaSize,
    );

    // 2. Section 0 entry at 0x240
    const int mediaStart = headerSize ~/ blockSize; // 0xC00 / 0x200 = 6
    final int mediaEnd = totalNcaSize ~/ blockSize;
    view.setUint32(0x240, mediaStart, Endian.little);
    view.setUint32(0x244, mediaEnd, Endian.little);
    view.setUint8(0x248, 1); // Section enabled

    // 3. FsHeader 0 at 0x400 (0x200 bytes)
    final Uint8List fsHeader0 = Uint8List(0x200);
    final ByteData fsView0 = ByteData.sublistView(fsHeader0);
    fsView0.setUint16(0x00, 2, Endian.little); // Version = 2
    fsView0.setUint8(0x02, partitionType);
    fsView0.setUint8(0x03, hashType);
    fsView0.setUint8(0x04, cryptTypeNone); // Plaintext
    setupFsSuperblock(fsView0);

    // Copy FsHeader 0 to offset 0x400
    ncaBuffer.setRange(0x400, 0x600, fsHeader0);

    // Compute SHA-256 of FsHeader 0 -> write to section_hashes[0] at 0x280
    final fsHash0 = sha256.convert(fsHeader0).bytes;
    ncaBuffer.setRange(0x280, 0x2A0, fsHash0);

    // 4. Section 0 Data payload at 0xC00
    ncaBuffer.setRange(0xC00, 0xC00 + sectionData.length, sectionData);

    return ncaBuffer;
  }

  /// Assembles an NCA3 container with two partition sections (Section 0 and Section 1).
  static Uint8List _buildTwoSectionNca({
    required int contentType,
    required BigInt titleId,
    required int sec0PartitionType,
    required int sec0FsType,
    required int sec0HashType,
    required Uint8List sec0Data,
    required void Function(ByteData fsView) setupSec0FsSuperblock,
    required int sec1PartitionType,
    required int sec1FsType,
    required int sec1HashType,
    required Uint8List sec1Data,
    required void Function(ByteData fsView) setupSec1FsSuperblock,
  }) {
    // Pad sections to 0x200 block boundaries
    final int sec0Pad = (blockSize - (sec0Data.length % blockSize)) % blockSize;
    final int sec0SizeAligned = sec0Data.length + sec0Pad;

    final int sec1Pad = (blockSize - (sec1Data.length % blockSize)) % blockSize;
    final int sec1SizeAligned = sec1Data.length + sec1Pad;

    final int totalNcaSize = headerSize + sec0SizeAligned + sec1SizeAligned;
    final Uint8List ncaBuffer = Uint8List(totalNcaSize);
    final ByteData view = ByteData.sublistView(ncaBuffer);

    // 1. Base Header
    _writeBaseNcaHeader(
      view: view,
      contentType: contentType,
      titleId: titleId,
      totalSize: totalNcaSize,
    );

    // 2. Section Entries
    const int sec0MediaStart = headerSize ~/ blockSize; // 6
    final int sec0MediaEnd = sec0MediaStart + (sec0SizeAligned ~/ blockSize);

    final int sec1MediaStart = sec0MediaEnd;
    final int sec1MediaEnd = sec1MediaStart + (sec1SizeAligned ~/ blockSize);

    // Section 0 Entry at 0x240
    view.setUint32(0x240, sec0MediaStart, Endian.little);
    view.setUint32(0x244, sec0MediaEnd, Endian.little);
    view.setUint8(0x248, 1);

    // Section 1 Entry at 0x250
    view.setUint32(0x250, sec1MediaStart, Endian.little);
    view.setUint32(0x254, sec1MediaEnd, Endian.little);
    view.setUint8(0x258, 1);

    // 3. FsHeader 0 at 0x400
    final Uint8List fsHeader0 = Uint8List(0x200);
    final ByteData fsView0 = ByteData.sublistView(fsHeader0);
    fsView0.setUint16(0x00, 2, Endian.little);
    fsView0.setUint8(0x02, sec0PartitionType);
    fsView0.setUint8(0x03, sec0HashType);
    fsView0.setUint8(0x04, cryptTypeNone);
    setupSec0FsSuperblock(fsView0);
    ncaBuffer.setRange(0x400, 0x600, fsHeader0);

    final fsHash0 = sha256.convert(fsHeader0).bytes;
    ncaBuffer.setRange(0x280, 0x2A0, fsHash0);

    // 4. FsHeader 1 at 0x600
    final Uint8List fsHeader1 = Uint8List(0x200);
    final ByteData fsView1 = ByteData.sublistView(fsHeader1);
    fsView1.setUint16(0x00, 2, Endian.little);
    fsView1.setUint8(0x02, sec1PartitionType);
    fsView1.setUint8(0x03, sec1HashType);
    fsView1.setUint8(0x04, cryptTypeNone);
    setupSec1FsSuperblock(fsView1);
    ncaBuffer.setRange(0x600, 0x800, fsHeader1);

    final fsHash1 = sha256.convert(fsHeader1).bytes;
    ncaBuffer.setRange(0x2A0, 0x2C0, fsHash1);

    // 5. Section Data Payloads
    const int sec0DataOffset = headerSize;
    ncaBuffer.setRange(
        sec0DataOffset, sec0DataOffset + sec0Data.length, sec0Data);

    final int sec1DataOffset = headerSize + sec0SizeAligned;
    ncaBuffer.setRange(
        sec1DataOffset, sec1DataOffset + sec1Data.length, sec1Data);

    return ncaBuffer;
  }

  /// Writes standard NCA3 base header fields (0x200..0x240).
  static void _writeBaseNcaHeader({
    required ByteData view,
    required int contentType,
    required BigInt titleId,
    required int totalSize,
  }) {
    // Magic 'NCA3' at 0x200
    view.setUint8(0x200, 0x4E); // 'N'
    view.setUint8(0x201, 0x43); // 'C'
    view.setUint8(0x202, 0x41); // 'A'
    view.setUint8(0x203, 0x33); // '3'

    view.setUint8(0x204, 0); // DistributionType = Download (0)
    view.setUint8(0x205, contentType);
    view.setUint8(0x206, 2); // KeyGenerationOld
    view.setUint8(0x207, 0); // KeyAreaEncryptionKeyIndex

    // ContentSize at 0x208 (in bytes, 64-bit uint LE)
    writeUint64Le(view, 0x208, BigInt.from(totalSize));

    // TitleId / ProgramId at 0x210
    writeUint64Le(view, 0x210, titleId);

    view.setUint32(0x218, 0, Endian.little); // ContentIndex

    // SdkAddonVersion at 0x21C (e.g. 0.12.17.0 = 0x000C1100)
    view.setUint32(0x21C, 0x000C1100, Endian.little);

    view.setUint8(0x220, 1); // KeyGeneration
    view.setUint8(0x221, 0); // SignatureKeyGeneration
  }

  /// Builds IVFC (Integrity Verification File Container) levels for RomFS data.
  static _IvfcHierarchy _buildIvfcHierarchy(Uint8List romfsBytes) {
    // Level 5: RomFS data padded to 0x4000
    final int lvl5Pad =
        (ivfcHashBlockSize - (romfsBytes.length % ivfcHashBlockSize)) %
            ivfcHashBlockSize;
    final Uint8List level5 = Uint8List(romfsBytes.length + lvl5Pad);
    level5.setRange(0, romfsBytes.length, romfsBytes);

    // Levels 4 down to 0: hash table of previous level padded to 0x4000
    final Uint8List level4 = _buildIvfcLevel(level5, ivfcHashBlockSize);
    final Uint8List level3 = _buildIvfcLevel(level4, ivfcHashBlockSize);
    final Uint8List level2 = _buildIvfcLevel(level3, ivfcHashBlockSize);
    final Uint8List level1 = _buildIvfcLevel(level2, ivfcHashBlockSize);
    final Uint8List level0 = _buildIvfcLevel(level1, ivfcHashBlockSize);

    // Master hash: SHA-256 of Level 0 data
    final masterHash = Uint8List.fromList(sha256.convert(level0).bytes);

    final levels = [level0, level1, level2, level3, level4, level5];
    final originalSizes = [
      level0.length,
      level1.length,
      level2.length,
      level3.length,
      level4.length,
      romfsBytes.length, // level 5 data size
    ];

    // Compute logical offsets
    final List<int> logicalOffsets = List.filled(6, 0);
    int currentOffset = 0;
    for (int i = 0; i < 6; i++) {
      logicalOffsets[i] = currentOffset;
      currentOffset += originalSizes[i];
    }

    // Concatenate levels 0..5 in sequential order for section payload
    final BytesBuilder builder = BytesBuilder();
    for (var lvl in levels) {
      builder.add(lvl);
    }

    return _IvfcHierarchy(
      masterHash: masterHash,
      logicalOffsets: logicalOffsets,
      hashDataSizes: originalSizes,
      sectionPayload: builder.toBytes(),
    );
  }

  static Uint8List _buildIvfcLevel(Uint8List srcLevel, int blockSize) {
    final BytesBuilder bb = BytesBuilder();
    for (int i = 0; i < srcLevel.length; i += blockSize) {
      final chunkEnd =
          (i + blockSize < srcLevel.length) ? i + blockSize : srcLevel.length;
      final chunk = srcLevel.sublist(i, chunkEnd);
      final hash = sha256.convert(chunk).bytes;
      bb.add(hash);
    }
    final raw = bb.toBytes();
    final pad = (blockSize - (raw.length % blockSize)) % blockSize;
    if (pad > 0) {
      bb.add(Uint8List(pad));
    }
    return bb.toBytes();
  }

  /// Writes IVFC RomFS superblock into FsHeader (starting at offset 0x08).
  static void _writeIvfcSuperblock(ByteData fsView, _IvfcHierarchy ivfc) {
    // 0x08: Magic "IVFC" (0x43465649)
    fsView.setUint8(0x08, 0x49); // 'I'
    fsView.setUint8(0x09, 0x56); // 'V'
    fsView.setUint8(0x0A, 0x46); // 'F'
    fsView.setUint8(0x0B, 0x43); // 'C'
    fsView.setUint32(0x0C, 0x00020000, Endian.little); // id = 0x20000
    fsView.setUint32(0x10, 0x20, Endian.little); // master_hash_size = 0x20
    fsView.setUint32(0x14, 0x07, Endian.little); // num_levels = 7

    // Level headers 0..5 (each 0x18 bytes, starting at 0x18)
    for (int i = 0; i < 6; i++) {
      final int off = 0x18 + i * 0x18;
      fsView.setUint64(off + 0x00, ivfc.logicalOffsets[i], Endian.little);
      fsView.setUint64(off + 0x08, ivfc.hashDataSizes[i], Endian.little);
      fsView.setUint32(off + 0x10, 0x0E, Endian.little); // 1 << 14 = 0x4000
      fsView.setUint32(off + 0x14, 0, Endian.little); // Reserved
    }

    // 0xA0-0xC0: reserved / signature salt (already zeroed, explicitly noted).
    // 0xC0-0xE0: Master hash (0x20 bytes) at FsHeader offset 0xC8.
    for (int i = 0; i < 0x20; i++) {
      fsView.setUint8(0xC8 + i, ivfc.masterHash[i]);
    }
  }

  /// Builds PFS0 section payload with hash table and padding.
  ///
  /// The [hashBlockSize] is the PFS0 hash block size used for this section
  /// (`0x10000` for ExeFS, `0x1000` for Meta). The master hash is computed
  /// over the raw (unpadded) hash table, while the on-disk hash table is
  /// padded to [pfs0PaddingSize] (`0x200`) as hacPack does.
  static _Pfs0SectionPayload _buildPfs0SectionPayload(
    Uint8List pfs0Bytes, {
    required int hashBlockSize,
  }) {
    // 1. Build hash table over blocks of the supplied hash block size.
    final BytesBuilder htBuilder = BytesBuilder();
    for (int i = 0; i < pfs0Bytes.length; i += hashBlockSize) {
      final chunkEnd = (i + hashBlockSize < pfs0Bytes.length)
          ? i + hashBlockSize
          : pfs0Bytes.length;
      final chunk = pfs0Bytes.sublist(i, chunkEnd);
      htBuilder.add(sha256.convert(chunk).bytes);
    }
    final Uint8List rawHashTable = htBuilder.toBytes();

    // 2. Pad the hash table to the hacPack PFS0 padding boundary (0x200).
    final int htPad =
        (pfs0PaddingSize - (rawHashTable.length % pfs0PaddingSize)) %
            pfs0PaddingSize;
    final Uint8List paddedHashTable = Uint8List(rawHashTable.length + htPad);
    paddedHashTable.setRange(0, rawHashTable.length, rawHashTable);

    // 3. Master hash = SHA-256 of the raw (unpadded) hash table.
    final masterHash = Uint8List.fromList(sha256.convert(rawHashTable).bytes);

    // 4. Payload = [paddedHashTable, pfs0Bytes]
    final BytesBuilder payloadBuilder = BytesBuilder();
    payloadBuilder.add(paddedHashTable);
    payloadBuilder.add(pfs0Bytes);

    return _Pfs0SectionPayload(
      masterHash: masterHash,
      hashTableSize: rawHashTable.length,
      hashBlockSize: hashBlockSize,
      pfs0Offset: paddedHashTable.length,
      pfs0Size: pfs0Bytes.length,
      payload: payloadBuilder.toBytes(),
    );
  }

  /// Writes PFS0 superblock into FsHeader (starting at offset 0x08).
  static void _writePfs0Superblock(
      ByteData fsView, _Pfs0SectionPayload section) {
    // 0x08: Master hash (0x20 bytes)
    for (int i = 0; i < 0x20; i++) {
      fsView.setUint8(0x08 + i, section.masterHash[i]);
    }
    fsView.setUint32(0x28, section.hashBlockSize, Endian.little);
    fsView.setUint32(0x2C, 0x02, Endian.little); // always_2
    fsView.setUint64(0x30, 0, Endian.little); // hash_table_offset
    fsView.setUint64(0x38, section.hashTableSize, Endian.little);
    fsView.setUint64(0x40, section.pfs0Offset, Endian.little);
    fsView.setUint64(0x48, section.pfs0Size, Endian.little);
  }

  // --- General Utilities ---

  /// Parses 64-bit Title ID from hexadecimal string and normalizes it to a
  /// valid Switch application title ID.
  ///
  /// The low 4 bits are the program index; emulators and loaders search for the
  /// main program NCA matching program index 0. The low nibble is cleared so
  /// the title ID maps to program index 0. The caller (UI/validation layer) is
  /// responsible for keeping the title ID inside the valid application range
  /// (0x0100... - 0x0F...).
  static BigInt parseTitleId(String hexId) {
    final cleanHex = hexId
        .replaceAll(RegExp(r'[^0-9A-Fa-f]'), '')
        .toUpperCase()
        .padLeft(16, '0');
    BigInt value = BigInt.tryParse(cleanHex, radix: 16) ?? BigInt.zero;

    // Program index is encoded in the low 4 bits. Force it to 0.
    const programIndexMask = 0xF;
    value = value & ~BigInt.from(programIndexMask);

    return value;
  }

  /// Parses version string ('1.0.0' -> 0x00010000).
  static int parseVersionNumber(String version) {
    final parts = version.split('.');
    int major = 1;
    int minor = 0;
    int micro = 0;
    if (parts.isNotEmpty) major = int.tryParse(parts[0]) ?? 1;
    if (parts.length > 1) minor = int.tryParse(parts[1]) ?? 0;
    if (parts.length > 2) micro = int.tryParse(parts[2]) ?? 0;

    return ((major & 0xFFFF) << 16) | ((minor & 0xFF) << 8) | (micro & 0xFF);
  }

  /// Writes 64-bit Little Endian integer.
  static void writeUint64Le(ByteData view, int offset, BigInt value) {
    BigInt temp = value;
    for (int i = 0; i < 8; i++) {
      view.setUint8(offset + i, (temp & BigInt.from(0xFF)).toInt());
      temp = temp >> 8;
    }
  }

  /// Writes 48-bit Little Endian integer (used in CNMT size fields).
  static void writeUint48Le(ByteData view, int offset, int size) {
    int temp = size;
    for (int i = 0; i < 6; i++) {
      view.setUint8(offset + i, temp & 0xFF);
      temp = temp >> 8;
    }
  }

  /// Converts bytes to lowercase hexadecimal string.
  static String _bytesToHex(List<int> bytes) {
    final StringBuffer buffer = StringBuffer();
    for (var b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString().toLowerCase();
  }
}

class _IvfcHierarchy {
  final Uint8List masterHash;
  final List<int> logicalOffsets;
  final List<int> hashDataSizes;
  final Uint8List sectionPayload;

  _IvfcHierarchy({
    required this.masterHash,
    required this.logicalOffsets,
    required this.hashDataSizes,
    required this.sectionPayload,
  });
}

class _Pfs0SectionPayload {
  final Uint8List masterHash;
  final int hashTableSize;
  final int hashBlockSize;
  final int pfs0Offset;
  final int pfs0Size;
  final Uint8List payload;

  _Pfs0SectionPayload({
    required this.masterHash,
    required this.hashTableSize,
    required this.hashBlockSize,
    required this.pfs0Offset,
    required this.pfs0Size,
    required this.payload,
  });
}
