// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/file_saver_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('nspff_file_saver_test_');
    FileSaverService.testCandidateDirectories = null;
  });

  tearDown(() async {
    FileSaverService.testCandidateDirectories = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FileSaverService SharedPreferences & Preferences Tests', () {
    test('Reads null when no target folder is saved', () async {
      final saved = await FileSaverService.getSavedTargetFolder();
      expect(saved, isNull);
    });

    test('Persists and retrieves custom target folder', () async {
      const customPath = '/custom/switch/nsp/output';
      await FileSaverService.setSavedTargetFolder(customPath);

      final retrieved = await FileSaverService.getSavedTargetFolder();
      expect(retrieved, equals(customPath));
    });

    test('Clearing target folder removes entry', () async {
      await FileSaverService.setSavedTargetFolder('/some/path');
      await FileSaverService.clearSavedTargetFolder();

      final retrieved = await FileSaverService.getSavedTargetFolder();
      expect(retrieved, isNull);
    });

    test('Setting empty or null target folder clears preference', () async {
      await FileSaverService.setSavedTargetFolder('/some/path');
      await FileSaverService.setSavedTargetFolder('');
      expect(await FileSaverService.getSavedTargetFolder(), isNull);

      await FileSaverService.setSavedTargetFolder('/some/path');
      await FileSaverService.setSavedTargetFolder(null);
      expect(await FileSaverService.getSavedTargetFolder(), isNull);
    });

    test('getDisplayTargetFolder returns custom folder or default label',
        () async {
      expect(
          await FileSaverService.getDisplayTargetFolder(), contains('Default'));

      await FileSaverService.setSavedTargetFolder('/storage/custom');
      expect(await FileSaverService.getDisplayTargetFolder(),
          equals('/storage/custom'));
    });
  });

  group('FileSaverService Security Tests', () {
    test('saveNspFile rejects parent-directory traversal', () async {
      final bytes = Uint8List.fromList([0x50, 0x46, 0x53, 0x30]);
      final marker = 'traversal_marker_${tempDir.hashCode}.nsp';
      final outsidePath = p.normalize(p.join(tempDir.path, '..', marker));

      final savedPath = await FileSaverService.saveNspFile(
        '../$marker',
        bytes,
        targetDir: tempDir.path,
      );

      expect(savedPath, isNull);
      expect(await File(outsidePath).exists(), isFalse);
    });

    test('saveNspFile rejects absolute paths', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final markerFile = File(p.join(tempDir.path, 'absolute_marker.nsp'));
      await markerFile.writeAsBytes([0xDE, 0xAD, 0xBE, 0xEF]);

      final savedPath = await FileSaverService.saveNspFile(
        markerFile.path,
        bytes,
        targetDir: tempDir.path,
      );

      expect(savedPath, isNull);
      // The pre-existing marker file must not have been overwritten.
      expect(await markerFile.readAsBytes(),
          equals(Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF])));
    });

    test('saveNspFile rejects backslash and Windows drive paths', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      final savedPath = await FileSaverService.saveNspFile(
        r'C:\Windows\System32\evil.nsp',
        bytes,
        targetDir: tempDir.path,
      );

      expect(savedPath, isNull);
    });

    test('saveNspFile rejects embedded path separators', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      final savedPath = await FileSaverService.saveNspFile(
        'subdir/game.nsp',
        bytes,
        targetDir: tempDir.path,
      );

      expect(savedPath, isNull);
      // Only the basename would have been written if sanitization had not
      // rejected the input, so ensure no such file was created.
      final unexpected = File(p.join(tempDir.path, 'game.nsp'));
      expect(await unexpected.exists(), isFalse);
    });

    test('saveToDownloads throws for unsafe filenames', () async {
      expect(
        () async => await FileSaverService.saveToDownloads(
          '../traversal.nsp',
          [1, 2],
          targetDir: tempDir.path,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('FileSaverService Modern Storage & SAF Fallback Tests', () {
    test('saveNspFile writes to explicit targetDir', () async {
      final explicitDir = p.join(tempDir.path, 'explicit_target');
      final bytes = Uint8List.fromList([0x50, 0x46, 0x53, 0x30]); // PFS0

      final savedPath = await FileSaverService.saveNspFile(
        'game_test.nsp',
        bytes,
        targetDir: explicitDir,
      );

      expect(savedPath, isNotNull);
      expect(savedPath, startsWith(explicitDir));
      final savedFile = File(savedPath!);
      expect(await savedFile.exists(), isTrue);
      expect(await savedFile.readAsBytes(), equals(bytes));
    });

    test('saveNspFile writes to persisted SharedPreferences folder', () async {
      final customDir = p.join(tempDir.path, 'pref_target');
      await FileSaverService.setSavedTargetFolder(customDir);

      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final savedPath =
          await FileSaverService.saveNspFile('test_pref.nsp', bytes);

      expect(savedPath, isNotNull);
      expect(savedPath, startsWith(customDir));
      expect(await File(savedPath!).exists(), isTrue);
    });

    test('saveNspFile falls back to next candidate if primary is inaccessible',
        () async {
      final invalidDir =
          Directory('/non_existent_read_only_root_dir_99999/test');
      final validFallback = Directory(p.join(tempDir.path, 'fallback_dir'));
      FileSaverService.testCandidateDirectories = [invalidDir, validFallback];

      final bytes = Uint8List.fromList([10, 20, 30]);
      final savedPath =
          await FileSaverService.saveNspFile('fallback_test.nsp', bytes);

      expect(savedPath, isNotNull);
      expect(savedPath, startsWith(validFallback.path));
      expect(await File(savedPath!).exists(), isTrue);
    });

    test('saveNspFile returns null if all candidate directories fail',
        () async {
      final invalidDir1 = Directory('/dev/null/forbidden_1');
      final invalidDir2 = Directory('/proc/forbidden_2');
      FileSaverService.testCandidateDirectories = [invalidDir1, invalidDir2];

      final bytes = Uint8List.fromList([1, 2]);
      final savedPath =
          await FileSaverService.saveNspFile('impossible.nsp', bytes);

      expect(savedPath, isNull);
    });

    test('saveToDownloads wrapper successfully saves and returns path',
        () async {
      final testDir = p.join(tempDir.path, 'downloads_target');
      final bytes = [9, 8, 7];

      final savedPath = await FileSaverService.saveToDownloads(
        'download_test.nsp',
        bytes,
        targetDir: testDir,
      );

      expect(savedPath, isNotEmpty);
      expect(await File(savedPath).exists(), isTrue);
    });

    test('saveToDownloads throws when all candidate directories fail',
        () async {
      FileSaverService.testCandidateDirectories = [
        Directory('/invalid_root_9999/a'),
      ];

      expect(
        () async => await FileSaverService.saveToDownloads(
          'fail.nsp',
          [1, 2],
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
