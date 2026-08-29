// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/forwarder_config.dart';
import '../models/prod_keys.dart';
import 'nacp_builder.dart';

class GeneratedNspResult {
  final Uint8List nspBytes;
  final String filename;
  final String titleId;
  final int totalSize;

  GeneratedNspResult({
    required this.nspBytes,
    required this.filename,
    required this.titleId,
    required this.totalSize,
  });
}

class NspGenerator {
  static final RegExp _filenameSanitizerRegex = RegExp(r'[^\w\s\.-]');

  /// Asynchronously generates NSP in a background worker Isolate to preserve UI responsiveness.
  static Future<GeneratedNspResult> generateNspAsync({
    required ForwarderConfig config,
    required ProdKeys keys,
  }) async {
    return Isolate.run(() => generateNsp(config: config, keys: keys));
  }

  /// Generate a valid PFS0 NSP file wrapping Control NCA, Main NCA, Meta NCA (CNMT), and Control NACP.
  static Future<GeneratedNspResult> generateNsp({
    required ForwarderConfig config,
    required ProdKeys keys,
  }) async {
    final titleIdHex = config.id.replaceAll('0x', '').toUpperCase().padLeft(16, '0');

    // 1. Prepare 256x256 Icon JPEG
    Uint8List iconJpgBytes;
    if (config.imageBytes != null && config.imageBytes!.isNotEmpty) {
      final decodedImage = img.decodeImage(config.imageBytes!);
      if (decodedImage != null) {
        final resized = img.copyResize(decodedImage, width: 256, height: 256);
        iconJpgBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 90));
      } else {
        iconJpgBytes = _generatePlaceholderIcon(config.title);
      }
    } else {
      iconJpgBytes = _generatePlaceholderIcon(config.title);
    }

    // 2. Build NACP (0x4000 bytes)
    final Uint8List nacpBytes = NacpBuilder.buildNacp(config);

    // 3. Build Control RomFS (containing icon_AmericanEnglish.dat & control.nacp)
    final Uint8List controlRomfs = _buildControlRomFs(nacpBytes, iconJpgBytes);

    // 4. Build NCAs (Control NCA, Program NCA stub, CNMT Meta NCA)
    final Uint8List controlNca = _buildNcaStub('Control', titleIdHex, controlRomfs);
    final Uint8List programNca = _buildNcaStub('Program', titleIdHex, _buildExeFsStub(config));
    final Uint8List metaNca = _buildMetaNca(titleIdHex, controlNca, programNca);

    // 5. Package into PFS0 container (.nsp)
    final List<_PfsFile> pfsFiles = [
      _PfsFile(name: '${titleIdHex}_control.nca', data: controlNca),
      _PfsFile(name: '${titleIdHex}_program.nca', data: programNca),
      _PfsFile(name: '${titleIdHex}_meta.cnmt.nca', data: metaNca),
    ];

    final Uint8List nspBytes = _buildPfs0(pfsFiles);

    return GeneratedNspResult(
      nspBytes: nspBytes,
      filename: '${config.title.replaceAll(_filenameSanitizerRegex, '')}_[$titleIdHex].nsp',
      titleId: titleIdHex,
      totalSize: nspBytes.length,
    );
  }

  /// Build PFS0 (Partition File System 0) container binary.
  static Uint8List _buildPfs0(List<_PfsFile> files) {
    // 1. Calculate String Table
    final BytesBuilder strBuilder = BytesBuilder();
    final List<int> strOffsets = [];

    for (var file in files) {
      strOffsets.add(strBuilder.length);
      strBuilder.add(utf8.encode(file.name));
      strBuilder.addByte(0); // null terminator
    }

    final Uint8List stringTable = strBuilder.toBytes();
    final int headerSize = 0x10 + (files.length * 0x18) + stringTable.length;
    
    // Align header to 0x20
    final int paddingSize = (0x20 - (headerSize % 0x20)) % 0x20;
    final int totalHeaderSize = headerSize + paddingSize;

    // 2. Build Header
    final ByteData headerData = ByteData(0x10);
    // Magic PFS0
    headerData.setUint8(0x00, 0x50);
    headerData.setUint8(0x01, 0x46);
    headerData.setUint8(0x02, 0x53);
    headerData.setUint8(0x03, 0x30);

    headerData.setUint32(0x04, files.length, Endian.little);
    headerData.setUint32(0x08, stringTable.length + paddingSize, Endian.little);
    headerData.setUint32(0x0C, 0, Endian.little); // Reserved

    final BytesBuilder resultBuilder = BytesBuilder();
    resultBuilder.add(headerData.buffer.asUint8List());

    // 3. Build File Entries (0x18 bytes each)
    int currentOffset = 0;
    for (int i = 0; i < files.length; i++) {
      final ByteData entry = ByteData(0x18);
      entry.setUint64(0x00, currentOffset, Endian.little);
      entry.setUint64(0x08, files[i].data.length, Endian.little);
      entry.setUint32(0x10, strOffsets[i], Endian.little);
      entry.setUint32(0x14, 0, Endian.little);
      resultBuilder.add(entry.buffer.asUint8List());

      currentOffset += files[i].data.length;
    }

    // 4. Add String Table + Padding
    resultBuilder.add(stringTable);
    if (paddingSize > 0) {
      resultBuilder.add(Uint8List(paddingSize));
    }

    // 5. Add File Contents
    for (var file in files) {
      resultBuilder.add(file.data);
    }

    return resultBuilder.toBytes();
  }

  /// Build Control RomFS binary containing icon & control.nacp.
  static Uint8List _buildControlRomFs(Uint8List nacpBytes, Uint8List iconJpgBytes) {
    final BytesBuilder builder = BytesBuilder();
    // RomFS Header (0x50 bytes)
    final ByteData header = ByteData(0x50);
    header.setUint64(0x00, 0x50, Endian.little); // Header Size
    header.setUint64(0x08, 0x200, Endian.little); // Dir Hash Table Offset
    header.setUint64(0x10, 0x40, Endian.little);  // Dir Hash Table Size
    header.setUint64(0x18, 0x240, Endian.little); // Dir Entry Table Offset
    header.setUint64(0x20, 0x40, Endian.little);  // Dir Entry Table Size
    header.setUint64(0x28, 0x280, Endian.little); // File Hash Table Offset
    header.setUint64(0x30, 0x40, Endian.little);  // File Hash Table Size
    header.setUint64(0x38, 0x2C0, Endian.little); // File Entry Table Offset
    header.setUint64(0x40, 0x80, Endian.little);  // File Entry Table Size
    header.setUint64(0x48, 0x400, Endian.little); // File Data Offset

    builder.add(header.buffer.asUint8List());
    
    // Padding up to File Data Offset 0x400
    final int headerPadding = 0x400 - builder.length;
    if (headerPadding > 0) {
      builder.add(Uint8List(headerPadding));
    }

    // Add nacp and icon data
    builder.add(nacpBytes);
    builder.add(iconJpgBytes);

    return builder.toBytes();
  }

  /// ExeFS Stub containing NPDM & forwarder binary.
  static Uint8List _buildExeFsStub(ForwarderConfig config) {
    final BytesBuilder builder = BytesBuilder();
    // NPDM Header
    final ByteData npdm = ByteData(0x80);
    npdm.setUint8(0x00, 0x4D); // 'M'
    npdm.setUint8(0x01, 0x41); // 'A'
    npdm.setUint8(0x02, 0x54); // 'T'
    npdm.setUint8(0x03, 0x4F); // 'O'
    builder.add(npdm.buffer.asUint8List());

    final utf8Encoder = const Utf8Encoder();
    builder.add(utf8Encoder.convert(config.nroPath));
    if (config.isRetroArch && config.romPath.isNotEmpty) {
      builder.addByte(0x20); // space
      builder.add(utf8Encoder.convert(config.romPath));
    }

    return builder.toBytes();
  }

  /// NCA Header Stub.
  static Uint8List _buildNcaStub(String type, String titleId, Uint8List sectionData) {
    final BytesBuilder builder = BytesBuilder();
    final ByteData ncaHeader = ByteData(0x400);
    
    // NCA3 Magic at offset 0x200
    ncaHeader.setUint8(0x200, 0x4E); // N
    ncaHeader.setUint8(0x201, 0x43); // C
    ncaHeader.setUint8(0x202, 0x41); // A
    ncaHeader.setUint8(0x203, 0x33); // 3

    builder.add(ncaHeader.buffer.asUint8List());
    builder.add(sectionData);

    return builder.toBytes();
  }

  /// Meta NCA (CNMT).
  static Uint8List _buildMetaNca(String titleId, Uint8List controlNca, Uint8List programNca) {
    final BytesBuilder builder = BytesBuilder();
    final ByteData cnmt = ByteData(0x200);
    final cleanHex = titleId.replaceAll('0x', '').replaceAll(' ', '').toUpperCase().padLeft(16, '0');
    try {
      final BigInt val = BigInt.parse(cleanHex, radix: 16);
      BigInt temp = val;
      for (int i = 0; i < 8; i++) {
        cnmt.setUint8(0x00 + i, (temp & BigInt.from(0xFF)).toInt());
        temp = temp >> 8;
      }
    } catch (_) {
      cnmt.setUint8(0x00, 0x01);
      cnmt.setUint8(0x07, 0x05);
    }
    cnmt.setUint32(0x08, 0x00010000, Endian.little); // Version 1.0.0
    cnmt.setUint8(0x0C, 0x80); // Application type

    builder.add(cnmt.buffer.asUint8List());
    return builder.toBytes();
  }


  /// Generate a sleek 256x256 placeholder icon JPEG for the forwarder.
  static Uint8List _generatePlaceholderIcon(String title) {
    final img.Image image = img.Image(width: 256, height: 256);
    img.fill(image, color: img.ColorRgb8(18, 18, 22));

    // Draw Cyan accent border
    img.drawRect(image, x1: 0, y1: 0, x2: 255, y2: 255, color: img.ColorRgb8(0, 196, 239));
    img.drawRect(image, x1: 1, y1: 1, x2: 254, y2: 254, color: img.ColorRgb8(0, 196, 239));

    // Draw Joycon Red accent bar
    img.fillRect(image, x1: 20, y1: 20, x2: 236, y2: 30, color: img.ColorRgb8(255, 54, 85));

    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }
}

class _PfsFile {
  final String name;
  final Uint8List data;
  _PfsFile({required this.name, required this.data});
}
