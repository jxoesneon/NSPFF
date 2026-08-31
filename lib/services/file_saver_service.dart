// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modern Android Storage Access Framework (SAF) & Scoped Storage compliant file saver.
///
/// Features:
/// - Allows custom folder selection via [FilePicker.getDirectoryPath].
/// - Persists target folder preference in [SharedPreferences].
/// - Implements graceful fallback resolution (Public Downloads -> App External -> Documents -> Temp).
/// - Modern Scoped Storage compliant for Android 11+ (API 30-36).
class FileSaverService {
  /// Preference key for the persisted custom output folder.
  static const String targetFolderKey = 'custom_target_folder';

  /// Optional candidate directories override for unit testing.
  static List<Directory>? testCandidateDirectories;

  /// Whitelist for safe filename characters: word characters, spaces, dots,
  /// hyphens, plus signs, brackets, and parentheses.
  static final RegExp _safeFilenameRegex = RegExp(r'^[\w.\-+\[\]\(\) ]+$');

  /// Maximum allowed filename length.
  static const int _maxFilenameLength = 200;

  /// Retrieves the persisted custom target folder preference from [SharedPreferences],
  /// or null if none is configured.
  static Future<String?> getSavedTargetFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(targetFolderKey);
  }

  /// Sets or removes the persisted custom target folder preference.
  static Future<void> setSavedTargetFolder(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await prefs.remove(targetFolderKey);
    } else {
      await prefs.setString(targetFolderKey, path.trim());
    }
  }

  /// Clears the persisted custom target folder preference.
  static Future<void> clearSavedTargetFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(targetFolderKey);
  }

  /// Launches the native Storage Access Framework (SAF) folder picker
  /// using [FilePicker.getDirectoryPath].
  ///
  /// If a directory is selected, saves it to [SharedPreferences] and returns it.
  static Future<String?> pickTargetFolder() async {
    try {
      final selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select NSP Export Directory',
      );
      if (selectedPath != null && selectedPath.trim().isNotEmpty) {
        final trimmed = selectedPath.trim();
        await setSavedTargetFolder(trimmed);
        return trimmed;
      }
    } catch (_) {
      // Gracefully handle platform exceptions or user cancellation
    }
    return null;
  }

  /// Returns a human-friendly display string for the active export target folder.
  static Future<String> getDisplayTargetFolder() async {
    final saved = await getSavedTargetFolder();
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    if (Platform.isAndroid) {
      return 'Default (Public Downloads / Scoped Storage)';
    }
    return 'Default (Downloads)';
  }

  /// Resolves candidate directories in prioritized order across Android and other platforms:
  /// 1. Public Downloads (/storage/emulated/0/Download, /sdcard/Download, or getDownloadsDirectory())
  /// 2. External app storage (Scoped Storage compliant: getExternalStorageDirectory())
  /// 3. App documents directory (getApplicationDocumentsDirectory())
  /// 4. App temporary directory (getTemporaryDirectory() or Directory.systemTemp)
  static Future<List<Directory>> _resolveCandidateDirectories() async {
    if (testCandidateDirectories != null) {
      return testCandidateDirectories!;
    }

    final List<Directory> candidates = [];

    if (Platform.isAndroid) {
      // 1. Primary Public Downloads (Standard Android locations)
      candidates.add(Directory('/storage/emulated/0/Download'));
      candidates.add(Directory('/sdcard/Download'));

      // 2. Scoped Storage: App-specific external storage (always writable without permissions on API 19+)
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          candidates.add(Directory(p.join(extDir.path, 'Download')));
          candidates.add(extDir);
        }
      } catch (_) {}

      // 3. Fallback: External storage downloads directory
      try {
        final extDirs = await getExternalStorageDirectories(
            type: StorageDirectory.downloads);
        if (extDirs != null) {
          candidates.addAll(extDirs);
        }
      } catch (_) {}
    } else {
      // Non-Android platforms (macOS, Windows, Linux, iOS)
      try {
        final dlDir = await getDownloadsDirectory();
        if (dlDir != null) {
          candidates.add(dlDir);
        }
      } catch (_) {}
    }

    // Common Fallbacks (Safe for all platforms and headless test runners)
    try {
      final docDir = await getApplicationDocumentsDirectory();
      candidates.add(docDir);
    } catch (_) {}

    try {
      final tempDir = await getTemporaryDirectory();
      candidates.add(tempDir);
    } catch (_) {}

    candidates.add(Directory.systemTemp);

    return candidates;
  }

  /// Sanitizes a caller-provided filename using [p.basename] and a strict
  /// character whitelist.
  ///
  /// Returns the safe basename, or `null` if the input contains path
  /// separators, traversal components, absolute paths, or disallowed
  /// characters.
  static String? _sanitizeFilename(String filename) {
    if (filename.isEmpty || filename.length > _maxFilenameLength) return null;
    // Reject backslash and Windows drive-letter separators immediately.
    if (filename.contains(r'\') || filename.contains(':')) return null;

    final base = p.basename(filename);
    // If [p.basename] changed the value, the input contained a path separator
    // or an absolute path prefix.
    if (base != filename) return null;

    if (base.isEmpty || base == '.' || base == '..') return null;
    if (!_safeFilenameRegex.hasMatch(base)) return null;
    return base;
  }

  /// Attempts to write bytes to [filename] inside [dir].
  /// Returns the absolute path if successful, or null if write failed.
  static Future<String?> _tryWriteFile(
    Directory dir,
    String filename,
    Uint8List bytes,
  ) async {
    final safeName = _sanitizeFilename(filename);
    if (safeName == null) return null;

    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final filePath = p.join(dir.path, safeName);
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      if (await file.exists()) {
        return filePath;
      }
    } catch (_) {
      // Write failed (e.g. Scoped Storage Permission Denied / Read-Only directory)
    }
    return null;
  }

  /// Modern Scoped Storage & SAF compliant NSP file saver.
  ///
  /// Resolves the destination directory in prioritized order:
  /// 1. Explicit [targetDir] (if provided and writable).
  /// 2. User-configured target folder from [SharedPreferences] (if set and writable).
  /// 3. Platform default Public Downloads.
  /// 4. Scoped Storage App External Storage (API 30+ fallback).
  /// 5. App Documents directory.
  /// 6. Temporary storage directory.
  ///
  /// Returns the saved file path if successful, or null if all attempts failed.
  static Future<String?> saveNspFile(
    String filename,
    Uint8List bytes, {
    String? targetDir,
  }) async {
    // 1. Explicit targetDir
    if (targetDir != null && targetDir.trim().isNotEmpty) {
      final saved =
          await _tryWriteFile(Directory(targetDir.trim()), filename, bytes);
      if (saved != null) return saved;
    }

    // 2. Persisted target folder
    try {
      final savedFolder = await getSavedTargetFolder();
      if (savedFolder != null && savedFolder.trim().isNotEmpty) {
        final saved =
            await _tryWriteFile(Directory(savedFolder.trim()), filename, bytes);
        if (saved != null) return saved;
      }
    } catch (_) {}

    // 3. Fallback candidates chain
    final candidates = await _resolveCandidateDirectories();
    for (final candidate in candidates) {
      final saved = await _tryWriteFile(candidate, filename, bytes);
      if (saved != null) return saved;
    }

    return null;
  }

  /// Saves the given bytes to the device\'s Downloads or resolved storage folder.
  /// Backward-compatible wrapper around [saveNspFile].
  static Future<String> saveToDownloads(
    String filename,
    List<int> bytes, {
    String? targetDir,
  }) async {
    final uint8Bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final savedPath =
        await saveNspFile(filename, uint8Bytes, targetDir: targetDir);
    if (savedPath == null) {
      throw Exception(
          'Could not save $filename to storage: All candidate directories failed or filename was unsafe.');
    }
    return savedPath;
  }
}
