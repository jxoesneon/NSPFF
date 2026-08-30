// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';
import '../models/forwarder_config.dart';

class NacpBuilder {
  static const int nacpSize = 0x4000;

  /// Builds a 0x4000 (16,384 byte) NACP binary buffer from [ForwarderConfig].
  static Uint8List buildNacp(ForwarderConfig config) {
    final Uint8List buffer = Uint8List(nacpSize);

    // 1. Language Entries: 16 supported languages, each 0x300 bytes (Title: 0x200, Publisher: 0x100)
    const utf8Encoder = Utf8Encoder();
    final titleBytes = utf8Encoder.convert(config.title);
    final pubBytes = utf8Encoder.convert(config.publisher);

    for (int lang = 0; lang < 16; lang++) {
      final int offset = lang * 0x300;

      // Copy Title (max 0x1FE bytes to leave null terminator)
      final int titleLen =
          titleBytes.length > 0x1FE ? 0x1FE : titleBytes.length;
      for (int i = 0; i < titleLen; i++) {
        buffer[offset + i] = titleBytes[i];
      }

      // Copy Publisher (max 0xFE bytes)
      final int pubOffset = offset + 0x200;
      final int pubLen = pubBytes.length > 0xFE ? 0xFE : pubBytes.length;
      for (int i = 0; i < pubLen; i++) {
        buffer[pubOffset + i] = pubBytes[i];
      }
    }

    // 2. Version String at 0x3060 (16 bytes max)
    final versionBytes = utf8Encoder.convert(config.version);
    final int versionLen = versionBytes.length > 15 ? 15 : versionBytes.length;
    for (int i = 0; i < versionLen; i++) {
      buffer[0x3060 + i] = versionBytes[i];
    }

    // 3. Title ID at 0x3038 (8-byte unsigned integer)
    _writeHexTitleId(buffer, 0x3038, config.id);

    // 4. Flags & Control Properties
    // Startup User Account: 0x3025 (0 = None/Disabled, 1 = Required)
    buffer[0x3025] = config.startupUserAccount ? 0x01 : 0x00;

    // Screenshot: 0x3034 (0 = Enabled, 1 = Disabled)
    buffer[0x3034] = config.screenshot ? 0x00 : 0x01;

    // Video Capture: 0x3035 (0 = Disabled, 1 = Enabled, 2 = Automatic)
    buffer[0x3035] = config.videoCapture ? 0x01 : 0x00;

    // Note: enableSvcDebug is an NPDM/ACID kernel capability, not an NACP
    // field. NACP offset 0x3036 is DataLossConfirmation; we intentionally
    // leave it at its default (0) to avoid misleading no-ops.

    // Logo Type: 0x30F0 (0 = Nintendo, 1 = Licensed by Nintendo, 2 = Distributed by Nintendo)
    buffer[0x30F0] = config.logoType.value & 0xFF;

    // Logo Handling: 0x30F1 (0 = Auto)
    buffer[0x30F1] = 0x00;

    return buffer;
  }

  static void _writeHexTitleId(Uint8List buffer, int offset, String hexId) {
    final cleanHex = hexId
        .replaceAll('0x', '')
        .replaceAll(' ', '')
        .toUpperCase()
        .padLeft(16, '0');
    try {
      final BigInt val = BigInt.parse(cleanHex, radix: 16);
      BigInt temp = val;
      for (int i = 0; i < 8; i++) {
        buffer[offset + i] = (temp & BigInt.from(0xFF)).toInt();
        temp = temp >> 8;
      }
    } catch (_) {
      // Fallback default ID 0x0500000000000001
      buffer[offset] = 0x01;
      buffer[offset + 7] = 0x05;
    }
  }
}
