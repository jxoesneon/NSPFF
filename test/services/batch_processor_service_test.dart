// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/models/prod_keys.dart';
import 'package:nspff/services/batch_processor_service.dart';
import 'package:nspff/services/network_install_service.dart';
import 'package:nspff/services/nsp_generator.dart';
import 'package:nspff/services/preset_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ProdKeys mockKeys;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('nspff_batch_test_');
    mockKeys = ProdKeys.parse(
      'header_key=11223344556677889900aabbccddeeff\nsd_seed=aabbccddeeff001122',
    );

    await NetworkInstallService.instance.stopServer();
    NetworkInstallService.instance.clearNsps();
  });

  tearDown(() async {
    await NetworkInstallService.instance.stopServer();
    NetworkInstallService.instance.clearNsps();

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  List<ForwarderConfig> generateTestConfigs(int count) {
    return List.generate(
      count,
      (i) => ForwarderConfig(
        id: (0x0500000000000010 + i).toRadixString(16).padLeft(16, '0'),
        title: 'Batch Game $i',
        publisher: 'Test Publisher',
        nroPath: '/retroarch/cores/snes9x_libretro_libswitch.nro',
        romPath: '/roms/snes/game$i.sfc',
        isRetroArch: true,
      ),
    );
  }

  group('BatchProcessorService Worker Pool & Concurrency Tests', () {
    test('Clamps worker pool concurrency between 2 and 8', () {
      expect(BatchProcessorService.calculateWorkerCount(1), equals(2));
      expect(BatchProcessorService.calculateWorkerCount(2), equals(2));
      expect(BatchProcessorService.calculateWorkerCount(4), equals(4));
      expect(BatchProcessorService.calculateWorkerCount(8), equals(8));
      expect(BatchProcessorService.calculateWorkerCount(16), equals(8));
      expect(BatchProcessorService.calculateWorkerCount(128), equals(8));

      final defaultWorkers = BatchProcessorService.defaultConcurrency;
      expect(defaultWorkers, greaterThanOrEqualTo(2));
      expect(defaultWorkers, lessThanOrEqualTo(8));

      final service = BatchProcessorService(concurrency: 1);
      expect(service.concurrency, equals(2));

      final highService = BatchProcessorService(concurrency: 32);
      expect(highService.concurrency, equals(8));
    });
  });

  group('BatchProcessorService Execution & Progress Lifecycle Tests', () {
    test('Executes batch using Isolate.run and tracks states to completion',
        () async {
      final configs = generateTestConfigs(3);
      final processor = BatchProcessorService(concurrency: 2);

      final List<BatchProgressUpdate> streamUpdates = [];
      final List<BatchProgressUpdate> callbackUpdates = [];

      final subscription = processor.progressStream.listen(streamUpdates.add);

      final result = await processor.processBatch(
        configs: configs,
        keys: mockKeys,
        targetDir: tempDir.path,
        onProgress: callbackUpdates.add,
      );

      await subscription.cancel();
      processor.dispose();

      expect(result.isSuccess, isTrue);
      expect(result.completedCount, equals(3));
      expect(result.failedCount, equals(0));
      expect(result.isCancelled, isFalse);
      expect(result.items.length, equals(3));

      for (var item in result.items) {
        expect(item.status, equals(BatchItemStatus.completed));
        expect(item.outputPath, isNotNull);
        expect(File(item.outputPath!).existsSync(), isTrue);
      }

      // Verify file-backed NSPs are registered for wireless install rather
      // than retained in memory.
      final registered = NetworkInstallService.instance.registeredNsps;
      expect(registered.length, equals(3));
      for (final source in registered.values) {
        expect(source.filePath, isNotNull);
        expect(source.filePath!, startsWith(tempDir.path));
        expect(source.length, greaterThan(0));
      }

      // Check stream & callback events
      expect(streamUpdates, isNotEmpty);
      expect(callbackUpdates, isNotEmpty);

      final lastUpdate = callbackUpdates.last;
      expect(lastUpdate.isCompleted, isTrue);
      expect(lastUpdate.percentage, equals(1.0));
      expect(lastUpdate.completedCount, equals(3));
      expect(lastUpdate.completedItems.length, equals(3));
      expect(lastUpdate.currentItemTitle, isNotEmpty);

      // Verify preset history was updated
      final history = await SavedPresetService.getHistory();
      expect(history.length, equals(3));
    });

    test('Handles empty configs list gracefully', () async {
      final processor = BatchProcessorService();
      final result = await processor.processBatch(
        configs: [],
        keys: mockKeys,
        targetDir: tempDir.path,
      );

      expect(result.isSuccess, isTrue);
      expect(result.completedCount, equals(0));
      expect(result.items, isEmpty);
      expect(result.isCancelled, isFalse);
    });

    test('Concurrent execution enforces max in-flight worker count', () async {
      int activeWorkersPeak = 0;
      int currentActive = 0;

      final configs = generateTestConfigs(6);

      final processor = BatchProcessorService(
        concurrency: 3,
        customGenerator: ({required config, required keys}) async {
          currentActive++;
          if (currentActive > activeWorkersPeak) {
            activeWorkersPeak = currentActive;
          }
          await Future<void>.delayed(const Duration(milliseconds: 30));
          currentActive--;
          return GeneratedNspResult(
            nspBytes: Uint8List.fromList([0x50, 0x46, 0x53, 0x30]),
            filename: '${config.title}.nsp',
            titleId: config.id,
            totalSize: 4,
          );
        },
        customFileSaver: (filename, bytes, {targetDir}) async {
          return p.join(tempDir.path, filename);
        },
        // Bypass the real network service in this test; it does not write
        // real files to disk, only verifies concurrency.
        networkRegistrar: (filename, filePath) {},
      );

      final result = await processor.processBatch(
        configs: configs,
        keys: mockKeys,
        targetDir: tempDir.path,
      );

      expect(result.isSuccess, isTrue);
      expect(result.completedCount, equals(6));
      expect(activeWorkersPeak, lessThanOrEqualTo(3));
    });
  });

  group('BatchProcessorService Cancellation & Error Recovery Tests', () {
    test('Cancels in-flight batch cleanly and halts queued items', () async {
      final configs = generateTestConfigs(8);

      final Completer<void> firstStarted = Completer<void>();

      late BatchProcessorService processor;
      processor = BatchProcessorService(
        concurrency: 2,
        customGenerator: ({required config, required keys}) async {
          if (!firstStarted.isCompleted) {
            firstStarted.complete();
          }
          // Delay to give test time to trigger cancel()
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return GeneratedNspResult(
            nspBytes: Uint8List.fromList([1, 2, 3]),
            filename: '${config.title}.nsp',
            titleId: config.id,
            totalSize: 3,
          );
        },
        customFileSaver: (filename, bytes, {targetDir}) async {
          return p.join(tempDir.path, filename);
        },
        // The fake file paths do not exist; bypass network registration.
        networkRegistrar: (filename, filePath) {},
      );

      final futureResult = processor.processBatch(
        configs: configs,
        keys: mockKeys,
        targetDir: tempDir.path,
      );

      await firstStarted.future;
      processor.cancel();

      final result = await futureResult;

      expect(processor.isCancelled, isTrue);
      expect(result.isCancelled, isTrue);
      expect(result.isSuccess, isFalse);

      // Cancelled items must be reported separately
      expect(result.cancelledCount, greaterThan(0));
      expect(result.failedCount, equals(0));
      expect(result.completedCount, lessThan(8));
      expect(
        result.items.where((i) => i.status == BatchItemStatus.cancelled),
        isNotEmpty,
      );
    });

    test(
        'Item failure records error without interrupting remaining batch items',
        () async {
      final configs = generateTestConfigs(4);

      final processor = BatchProcessorService(
        concurrency: 2,
        customGenerator: ({required config, required keys}) async {
          if (config.title.contains('Game 1')) {
            throw Exception('Corrupted RomFS data');
          }
          return GeneratedNspResult(
            nspBytes: Uint8List.fromList([0x50, 0x46, 0x53, 0x30]),
            filename: '${config.title}.nsp',
            titleId: config.id,
            totalSize: 4,
          );
        },
        customFileSaver: (filename, bytes, {targetDir}) async {
          return p.join(tempDir.path, filename);
        },
        // The fake file paths do not exist; bypass network registration.
        networkRegistrar: (filename, filePath) {},
      );

      final result = await processor.processBatch(
        configs: configs,
        keys: mockKeys,
        targetDir: tempDir.path,
      );

      expect(result.isSuccess, isFalse);
      expect(result.completedCount, equals(3));
      expect(result.failedCount, equals(1));

      final failedItem =
          result.items.firstWhere((i) => i.status == BatchItemStatus.failed);
      expect(failedItem.error, contains('Corrupted RomFS data'));

      final completedItems =
          result.items.where((i) => i.status == BatchItemStatus.completed);
      expect(completedItems.length, equals(3));
    });

    test('Throws StateError if processBatch is called while already running',
        () async {
      final configs = generateTestConfigs(3);
      final processor = BatchProcessorService(
        concurrency: 2,
        customGenerator: ({required config, required keys}) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return GeneratedNspResult(
            nspBytes: Uint8List.fromList([1]),
            filename: 'test.nsp',
            titleId: '0500000000000001',
            totalSize: 1,
          );
        },
      );

      final firstBatch = processor.processBatch(
        configs: configs,
        keys: mockKeys,
        targetDir: tempDir.path,
      );

      expect(
        () => processor.processBatch(
          configs: configs,
          keys: mockKeys,
          targetDir: tempDir.path,
        ),
        throwsA(isA<StateError>()),
      );

      await firstBatch;
    });
  });
}
