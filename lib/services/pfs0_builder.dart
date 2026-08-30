// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';

/// A single file entry inside a PFS0 (Partition File System 0) container.
class Pfs0File {
  /// File name as it appears in the PFS0 string table.
  final String name;

  /// Raw file contents.
  final Uint8List data;

  Pfs0File({required this.name, required this.data});
}

/// Builds Nintendo Switch PFS0 (Partition File System 0) containers.
///
/// Used for both the outer `.nsp` package and the inner ExeFS PFS0 inside
/// Program NCAs.
class Pfs0Builder {
  /// Builds a PFS0 container from the supplied [files].
  ///
  /// The string table is aligned to [stringTableAlignment] bytes (default
  /// `0x20`). File data is placed immediately after the header.
  static Uint8List build(List<Pfs0File> files,
      {int stringTableAlignment = 0x20}) {
    if (files.isEmpty) {
      throw ArgumentError.value(
          files, 'files', 'PFS0 must contain at least one file');
    }

    final BytesBuilder stringTableBuilder = BytesBuilder();
    final List<int> stringOffsets = [];

    for (final file in files) {
      stringOffsets.add(stringTableBuilder.length);
      stringTableBuilder.add(utf8.encode(file.name));
      stringTableBuilder.addByte(0); // null-terminated
    }

    final Uint8List rawStringTable = stringTableBuilder.toBytes();
    final int strPad = (stringTableAlignment -
            (rawStringTable.length % stringTableAlignment)) %
        stringTableAlignment;
    final int stringTableSizeAligned = rawStringTable.length + strPad;

    final int headerSize =
        0x10 + (files.length * 0x18) + stringTableSizeAligned;

    int totalDataSize = 0;
    for (final file in files) {
      totalDataSize += file.data.length;
    }

    final Uint8List buffer = Uint8List(headerSize + totalDataSize);
    final ByteData view = ByteData.sublistView(buffer);

    // PFS0 magic
    view.setUint8(0x00, 0x50); // 'P'
    view.setUint8(0x01, 0x46); // 'F'
    view.setUint8(0x02, 0x53); // 'S'
    view.setUint8(0x03, 0x30); // '0'

    view.setUint32(0x04, files.length, Endian.little);
    view.setUint32(0x08, stringTableSizeAligned, Endian.little);
    view.setUint32(0x0C, 0, Endian.little); // Reserved

    // File entries (0x18 bytes each)
    int currentOffset = 0;
    for (int i = 0; i < files.length; i++) {
      final int entryOffset = 0x10 + i * 0x18;
      view.setUint64(entryOffset + 0x00, currentOffset, Endian.little);
      view.setUint64(entryOffset + 0x08, files[i].data.length, Endian.little);
      view.setUint32(entryOffset + 0x10, stringOffsets[i], Endian.little);
      view.setUint32(entryOffset + 0x14, 0, Endian.little); // Reserved
      currentOffset += files[i].data.length;
    }

    // String table (already padded by the zeroed buffer allocation)
    final int strDest = 0x10 + files.length * 0x18;
    buffer.setRange(strDest, strDest + rawStringTable.length, rawStringTable);

    // File data
    int fileDataDest = headerSize;
    for (final file in files) {
      buffer.setRange(fileDataDest, fileDataDest + file.data.length, file.data);
      fileDataDest += file.data.length;
    }

    return buffer;
  }

  /// Builds a PFS0 container containing a single [fileData] entry named [name].
  static Uint8List buildSingle(String name, Uint8List data,
      {int stringTableAlignment = 0x20}) {
    return build([Pfs0File(name: name, data: data)],
        stringTableAlignment: stringTableAlignment);
  }
}
