// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/forwarder_config.dart';
import '../models/prod_keys.dart';
import 'nacp_builder.dart';
import 'nca_builder.dart';
import 'pfs0_builder.dart';

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

  /// Generate a valid PFS0 NSP file wrapping real Control NCA, Main Program NCA, and Meta NCA (CNMT).
  static Future<GeneratedNspResult> generateNsp({
    required ForwarderConfig config,
    required ProdKeys keys,
  }) async {
    final titleIdHex = NcaBuilder.parseTitleId(config.id)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(16, '0');

    // 1. Prepare 256x256 Icon JPEG (< 0x20000 bytes to avoid home menu issues)
    final Uint8List iconJpgBytes = _prepareIcon(config);

    // 2. Build NACP (0x4000 bytes)
    final Uint8List nacpBytes = NacpBuilder.buildNacp(config);

    // 3. Build Control NCA (with RomFS containing control.nacp and icon_AmericanEnglish.dat)
    final NcaResult controlNca = NcaBuilder.buildControlNca(
      config: config,
      nacpBytes: nacpBytes,
      iconBytes: iconJpgBytes,
    );

    // 4. Build Program NCA (with ExeFS forwarder stub and Program RomFS redirection)
    final NcaResult programNca = NcaBuilder.buildProgramNca(
      config: config,
    );

    // 5. Build Meta NCA with CNMT referencing Program and Control NCAs
    final Uint8List cnmtBytes = NcaBuilder.buildCnmtData(
      config: config,
      programNca: programNca,
      controlNca: controlNca,
    );
    final NcaResult metaNca = NcaBuilder.buildMetaNca(
      config: config,
      cnmtBytes: cnmtBytes,
    );

    // 6. Package into PFS0 container (.nsp) following Nintendo standard naming:
    //    <16-byte-hex-hash>.nca for Program NCA
    //    <16-byte-hex-hash>.nca for Control NCA
    //    <16-byte-hex-hash>.cnmt.nca for Meta NCA
    final List<Pfs0File> pfsFiles = [
      Pfs0File(name: programNca.filename, data: programNca.bytes),
      Pfs0File(name: controlNca.filename, data: controlNca.bytes),
      Pfs0File(name: metaNca.filename, data: metaNca.bytes),
    ];

    final Uint8List nspBytes = Pfs0Builder.build(pfsFiles);

    return GeneratedNspResult(
      nspBytes: nspBytes,
      filename:
          '${config.title.replaceAll(_filenameSanitizerRegex, '')}_[$titleIdHex].nsp',
      titleId: titleIdHex,
      totalSize: nspBytes.length,
    );
  }

  /// Resizes the source image and compresses it to a JPEG smaller than `0x20000` bytes.
  ///
  /// Throws a [StateError] if the image cannot be compressed below `0x20000`
  /// bytes even at quality 1.
  static Uint8List prepareIconJpeg(img.Image source) {
    final img.Image resized = img.copyResize(source, width: 256, height: 256);
    int quality = 90;
    Uint8List iconJpgBytes =
        Uint8List.fromList(img.encodeJpg(resized, quality: quality));

    while (iconJpgBytes.length >= 0x20000 && quality > 1) {
      quality -= quality > 10 ? 10 : 1;
      iconJpgBytes =
          Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }

    if (iconJpgBytes.length >= 0x20000) {
      throw StateError(
          'Unable to compress icon below 0x20000 bytes (required by the Switch home menu)');
    }

    return iconJpgBytes;
  }

  static Uint8List _prepareIcon(ForwarderConfig config) {
    if (config.imageBytes != null && config.imageBytes!.isNotEmpty) {
      final decodedImage = img.decodeImage(config.imageBytes!);
      if (decodedImage != null) {
        return prepareIconJpeg(decodedImage);
      }
    }
    return prepareIconJpeg(_generatePlaceholderImage(config.title));
  }

  /// Generate a sleek 256x256 placeholder icon image for the forwarder.
  static img.Image _generatePlaceholderImage(String title) {
    final img.Image image = img.Image(width: 256, height: 256);
    img.fill(image, color: img.ColorRgb8(18, 18, 22));

    // Draw Cyan accent border
    img.drawRect(image,
        x1: 0, y1: 0, x2: 255, y2: 255, color: img.ColorRgb8(0, 196, 239));
    img.drawRect(image,
        x1: 1, y1: 1, x2: 254, y2: 254, color: img.ColorRgb8(0, 196, 239));

    // Draw Joycon Red accent bar
    img.fillRect(image,
        x1: 20, y1: 20, x2: 236, y2: 30, color: img.ColorRgb8(255, 54, 85));

    return image;
  }
}
