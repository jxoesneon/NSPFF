// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';

/// Real, specification-compliant Nintendo Switch RomFS generator.
///
/// Produces binary RomFS images compatible with the Switch OS kernel (FS-srv),
/// libnx romfs driver, and CFW title managers (DBI, Tinfoil, Awoo, Goldleaf).
class RomfsBuilder {
  static const int headerSize = 0x50;
  static const int fileDataOffset = 0x200;
  static const int emptyEntry = 0xFFFFFFFF;

  /// Builds a RomFS binary containing [control.nacp] and [icon_AmericanEnglish.dat].
  static Uint8List buildControlRomfs({
    required Uint8List nacpBytes,
    required Uint8List iconBytes,
  }) {
    return build({
      'control.nacp': nacpBytes,
      'icon_AmericanEnglish.dat': iconBytes,
    });
  }

  /// Builds a RomFS binary for Program NCA section 1 containing
  /// forwarder redirection files [nextNroPath] and [nextArgv].
  static Uint8List buildProgramRomfs({
    required String nroPath,
    String? romPath,
  }) {
    final String formattedNro = _formatSdmcPath(nroPath);
    String formattedArgv = formattedNro;
    if (romPath != null && romPath.trim().isNotEmpty) {
      final String formattedRom = _formatSdmcPath(romPath);
      formattedArgv = '$formattedNro "$formattedRom"';
    }

    return build({
      'nextNroPath': Uint8List.fromList(utf8.encode(formattedNro)),
      'nextArgv': Uint8List.fromList(utf8.encode(formattedArgv)),
    });
  }

  /// Ensures an SD card path has the 'sdmc:' scheme prefix required by libnx / hbloader.
  static String _formatSdmcPath(String path) {
    var p = path.trim();
    if (p.startsWith('sdmc:')) return p;
    if (!p.startsWith('/')) p = '/$p';
    return 'sdmc:$p';
  }

  /// Calculates Nintendo Switch RomFS path hash.
  /// Algorithm: hash = ((hash >> 5) | (hash << 27)) ^ byte, starting with parentOffset ^ 123456789.
  static int calcPathHash(int parentOffset, List<int> nameBytes) {
    int hash = (parentOffset ^ 123456789) & 0xFFFFFFFF;
    for (int i = 0; i < nameBytes.length; i++) {
      hash = (((hash >> 5) | (hash << 27)) ^ nameBytes[i]) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Calculates prime bucket count for hash tables (standard RomFS heuristic).
  static int getHashTableCount(int numEntries) {
    if (numEntries < 3) return 3;
    if (numEntries < 19) return numEntries | 1;
    int count = numEntries;
    while (count % 2 == 0 ||
        count % 3 == 0 ||
        count % 5 == 0 ||
        count % 7 == 0 ||
        count % 11 == 0 ||
        count % 13 == 0 ||
        count % 17 == 0) {
      count++;
    }
    return count;
  }

  /// Builds a RomFS binary image from a map of relative file paths to file data bytes.
  static Uint8List build(Map<String, Uint8List> files) {
    // 1. Build directory and file tree
    final _RomfsDirNode rootNode = _RomfsDirNode(name: '');

    for (final entry in files.entries) {
      final cleanPath =
          entry.key.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
      final parts = cleanPath.split('/');
      _RomfsDirNode currentDir = rootNode;
      for (int i = 0; i < parts.length - 1; i++) {
        final part = parts[i];
        if (part.isEmpty) continue;
        currentDir = currentDir.getOrCreateSubdir(part);
      }
      final fileName = parts.last;
      currentDir.files.add(
        _RomfsFileNode(name: fileName, data: entry.value, parent: currentDir),
      );
    }

    // 2. Flatten directories and files with BFS/DFS traversal
    final List<_RomfsDirNode> allDirs = [];
    final List<_RomfsFileNode> allFiles = [];

    void collectDirsAndFiles(_RomfsDirNode dir) {
      allDirs.add(dir);
      // Sort subdirs alphabetically
      dir.subdirs.sort((a, b) => a.name.compareTo(b.name));
      // Sort files alphabetically
      dir.files.sort((a, b) => a.name.compareTo(b.name));

      for (var f in dir.files) {
        allFiles.add(f);
      }
      for (var sub in dir.subdirs) {
        collectDirsAndFiles(sub);
      }
    }

    collectDirsAndFiles(rootNode);

    // 3. Compute file data partition offsets (starting at fileDataOffset 0x200, each file aligned to 0x10)
    int currentFileDataOffset = 0;
    for (var file in allFiles) {
      // Align to 0x10
      currentFileDataOffset = (currentFileDataOffset + 0x0F) & ~0x0F;
      file.dataOffset = currentFileDataOffset;
      currentFileDataOffset += file.data.length;
    }
    final int totalFileDataPartitionSize =
        (currentFileDataOffset + 0x0F) & ~0x0F;

    // 4. Compute directory and file table entries and their entry offsets
    int currentDirTableOffset = 0;
    for (int i = 0; i < allDirs.length; i++) {
      final dir = allDirs[i];
      dir.entryOffset = currentDirTableOffset;
      // Entry size: 0x18 + align(nameLen, 4)
      final nameBytes = (dir == rootNode) ? <int>[] : utf8.encode(dir.name);
      final nameLen = nameBytes.length;
      final alignedNameLen = (nameLen + 3) & ~3;
      currentDirTableOffset += 0x18 + alignedNameLen;
    }
    final int dirTableSize = currentDirTableOffset;

    int currentFileTableOffset = 0;
    for (int i = 0; i < allFiles.length; i++) {
      final file = allFiles[i];
      file.entryOffset = currentFileTableOffset;
      // Entry size: 0x20 + align(nameLen, 4)
      final nameBytes = utf8.encode(file.name);
      final nameLen = nameBytes.length;
      final alignedNameLen = (nameLen + 3) & ~3;
      currentFileTableOffset += 0x20 + alignedNameLen;
    }
    final int fileTableSize = currentFileTableOffset;

    // 5. Setup sibling, childDir, and childFile pointers
    for (var dir in allDirs) {
      if (dir.subdirs.isNotEmpty) {
        dir.childDirOffset = dir.subdirs.first.entryOffset;
        for (int i = 0; i < dir.subdirs.length - 1; i++) {
          dir.subdirs[i].siblingOffset = dir.subdirs[i + 1].entryOffset;
        }
        dir.subdirs.last.siblingOffset = emptyEntry;
      } else {
        dir.childDirOffset = emptyEntry;
      }

      if (dir.files.isNotEmpty) {
        dir.childFileOffset = dir.files.first.entryOffset;
        for (int i = 0; i < dir.files.length - 1; i++) {
          dir.files[i].siblingOffset = dir.files[i + 1].entryOffset;
        }
        dir.files.last.siblingOffset = emptyEntry;
      } else {
        dir.childFileOffset = emptyEntry;
      }
    }

    // 6. Compute hash tables
    final int dirHashBucketCount = getHashTableCount(allDirs.length);
    final int fileHashBucketCount = getHashTableCount(allFiles.length);

    final List<int> dirHashTable = List.filled(dirHashBucketCount, emptyEntry);
    final List<int> fileHashTable =
        List.filled(fileHashBucketCount, emptyEntry);

    // Populate dirHashTable
    for (var dir in allDirs) {
      final nameBytes = (dir == rootNode) ? <int>[] : utf8.encode(dir.name);
      final parentOffset = (dir.parent != null) ? dir.parent!.entryOffset : 0;
      final rawHash = calcPathHash(parentOffset, nameBytes);
      final bucket = rawHash % dirHashBucketCount;

      dir.nextHashOffset = dirHashTable[bucket];
      dirHashTable[bucket] = dir.entryOffset;
    }

    // Populate fileHashTable
    for (var file in allFiles) {
      final nameBytes = utf8.encode(file.name);
      final parentOffset = file.parent?.entryOffset ?? 0;
      final rawHash = calcPathHash(parentOffset, nameBytes);
      final bucket = rawHash % fileHashBucketCount;

      file.nextHashOffset = fileHashTable[bucket];
      fileHashTable[bucket] = file.entryOffset;
    }

    // 7. Calculate table offsets in RomFS
    final int dirHashTableOffset =
        (fileDataOffset + totalFileDataPartitionSize + 3) & ~3;
    final int dirHashTableSize = dirHashBucketCount * 4;

    final int dirTableOffset = dirHashTableOffset + dirHashTableSize;
    final int fileHashTableOffset = dirTableOffset + dirTableSize;
    final int fileHashTableSize = fileHashBucketCount * 4;

    final int fileTableOffset = fileHashTableOffset + fileHashTableSize;
    final int totalRomfsSize = fileTableOffset + fileTableSize;

    // 8. Build binary buffer
    final Uint8List romfsBuffer = Uint8List(totalRomfsSize);
    final ByteData view = ByteData.sublistView(romfsBuffer);

    // 8a. Write Header (0x50 bytes)
    view.setUint64(0x00, headerSize, Endian.little);
    view.setUint64(0x08, dirHashTableOffset, Endian.little);
    view.setUint64(0x10, dirHashTableSize, Endian.little);
    view.setUint64(0x18, dirTableOffset, Endian.little);
    view.setUint64(0x20, dirTableSize, Endian.little);
    view.setUint64(0x28, fileHashTableOffset, Endian.little);
    view.setUint64(0x30, fileHashTableSize, Endian.little);
    view.setUint64(0x38, fileTableOffset, Endian.little);
    view.setUint64(0x40, fileTableSize, Endian.little);
    view.setUint64(0x48, fileDataOffset, Endian.little);

    // 8b. Write File Data
    for (var file in allFiles) {
      final int destOffset = fileDataOffset + file.dataOffset;
      romfsBuffer.setRange(
          destOffset, destOffset + file.data.length, file.data);
    }

    // 8c. Write Directory Hash Table
    for (int i = 0; i < dirHashBucketCount; i++) {
      view.setUint32(
          dirHashTableOffset + i * 4, dirHashTable[i], Endian.little);
    }

    // 8d. Write Directory Table
    for (var dir in allDirs) {
      final int dest = dirTableOffset + dir.entryOffset;
      final int parentOff = dir.parent?.entryOffset ?? 0;
      final nameBytes = (dir == rootNode) ? <int>[] : utf8.encode(dir.name);

      view.setUint32(dest + 0x00, parentOff, Endian.little);
      view.setUint32(dest + 0x04, dir.siblingOffset, Endian.little);
      view.setUint32(dest + 0x08, dir.childDirOffset, Endian.little);
      view.setUint32(dest + 0x0C, dir.childFileOffset, Endian.little);
      view.setUint32(dest + 0x10, dir.nextHashOffset, Endian.little);
      view.setUint32(dest + 0x14, nameBytes.length, Endian.little);
      if (nameBytes.isNotEmpty) {
        romfsBuffer.setRange(
            dest + 0x18, dest + 0x18 + nameBytes.length, nameBytes);
      }
    }

    // 8e. Write File Hash Table
    for (int i = 0; i < fileHashBucketCount; i++) {
      view.setUint32(
          fileHashTableOffset + i * 4, fileHashTable[i], Endian.little);
    }

    // 8f. Write File Table
    for (var file in allFiles) {
      final int dest = fileTableOffset + file.entryOffset;
      final int parentOff = file.parent?.entryOffset ?? 0;
      final nameBytes = utf8.encode(file.name);

      view.setUint32(dest + 0x00, parentOff, Endian.little);
      view.setUint32(dest + 0x04, file.siblingOffset, Endian.little);
      view.setUint64(dest + 0x08, file.dataOffset, Endian.little);
      view.setUint64(dest + 0x10, file.data.length, Endian.little);
      view.setUint32(dest + 0x18, file.nextHashOffset, Endian.little);
      view.setUint32(dest + 0x1C, nameBytes.length, Endian.little);
      romfsBuffer.setRange(
          dest + 0x20, dest + 0x20 + nameBytes.length, nameBytes);
    }

    return romfsBuffer;
  }
}

class _RomfsDirNode {
  final String name;
  _RomfsDirNode? parent;
  final List<_RomfsDirNode> subdirs = [];
  final List<_RomfsFileNode> files = [];

  int entryOffset = 0;
  int siblingOffset = RomfsBuilder.emptyEntry;
  int childDirOffset = RomfsBuilder.emptyEntry;
  int childFileOffset = RomfsBuilder.emptyEntry;
  int nextHashOffset = RomfsBuilder.emptyEntry;

  _RomfsDirNode({required this.name, this.parent});

  _RomfsDirNode getOrCreateSubdir(String subName) {
    for (var s in subdirs) {
      if (s.name == subName) return s;
    }
    final created = _RomfsDirNode(name: subName, parent: this);
    subdirs.add(created);
    return created;
  }
}

class _RomfsFileNode {
  final String name;
  final Uint8List data;
  _RomfsDirNode? parent;

  int dataOffset = 0;
  int entryOffset = 0;
  int siblingOffset = RomfsBuilder.emptyEntry;
  int nextHashOffset = RomfsBuilder.emptyEntry;

  _RomfsFileNode({required this.name, required this.data, this.parent});
}
