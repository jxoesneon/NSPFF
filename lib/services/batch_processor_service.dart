// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import '../models/forwarder_config.dart';
import '../models/prod_keys.dart';
import 'file_saver_service.dart';
import 'network_install_service.dart';
import 'nsp_generator.dart';
import 'preset_service.dart';

/// Lifecycle status for an individual batch item.
enum BatchItemStatus {
  queued,
  processing,
  completed,
  failed,
  cancelled,
}

/// Progress snapshot for a single item in a batch operation.
class BatchItemProgress {
  final int index;
  final ForwarderConfig config;
  final BatchItemStatus status;
  final String? outputPath;
  final String? error;

  const BatchItemProgress({
    required this.index,
    required this.config,
    required this.status,
    this.outputPath,
    this.error,
  });

  BatchItemProgress copyWith({
    BatchItemStatus? status,
    String? outputPath,
    String? error,
  }) {
    return BatchItemProgress(
      index: index,
      config: config,
      status: status ?? this.status,
      outputPath: outputPath ?? this.outputPath,
      error: error ?? this.error,
    );
  }
}

/// Emitted event/snapshot containing real-time batch processing metrics.
class BatchProgressUpdate {
  final int totalCount;
  final int completedCount;
  final int failedCount;
  final int cancelledCount;
  final int inProgressCount;
  final double percentage; // 0.0 to 1.0
  final Duration elapsedTime;
  final String currentItemTitle;
  final int activeWorkers;
  final bool isCancelled;
  final bool isCompleted;
  final List<BatchItemProgress> items;

  const BatchProgressUpdate({
    required this.totalCount,
    required this.completedCount,
    required this.failedCount,
    this.cancelledCount = 0,
    required this.inProgressCount,
    required this.percentage,
    required this.elapsedTime,
    required this.currentItemTitle,
    required this.activeWorkers,
    this.isCancelled = false,
    this.isCompleted = false,
    required this.items,
  });

  /// Convenience getter for all items that finished successfully.
  List<BatchItemProgress> get completedItems =>
      items.where((i) => i.status == BatchItemStatus.completed).toList();

  /// Convenience getter for all items that failed with an error.
  List<BatchItemProgress> get failedItems =>
      items.where((i) => i.status == BatchItemStatus.failed).toList();

  /// Convenience getter for all items that were cancelled.
  List<BatchItemProgress> get cancelledItems =>
      items.where((i) => i.status == BatchItemStatus.cancelled).toList();
}

/// Final summary result of a completed or cancelled batch operation.
class BatchResult {
  final List<BatchItemProgress> items;
  final int completedCount;
  final int failedCount;
  final int cancelledCount;
  final Duration totalDuration;
  final bool isCancelled;

  const BatchResult({
    required this.items,
    required this.completedCount,
    required this.failedCount,
    this.cancelledCount = 0,
    required this.totalDuration,
    required this.isCancelled,
  });

  bool get isSuccess => !isCancelled && failedCount == 0 && cancelledCount == 0;
}

typedef NspGenerationTask = Future<GeneratedNspResult> Function({
  required ForwarderConfig config,
  required ProdKeys keys,
});

typedef FileSaverTask = Future<String?> Function(
  String filename,
  Uint8List bytes, {
  String? targetDir,
});

typedef NspRegistrationTask = void Function(String filename, String filePath);

typedef HistoryRecorderTask = Future<void> Function(ForwarderConfig config);

/// High-performance parallel worker pool engine for batch NSP generation.
///
/// Features:
/// - Spawns concurrent background isolates via [Isolate.run].
/// - Concurrency scaled to [Platform.numberOfProcessors] clamped between 2 and 8.
/// - Live stream and callback progress reporting with elapsed time and item states.
/// - Graceful in-flight batch cancellation.
class BatchProcessorService {
  /// Default concurrency clamped to between 2 and 8 workers based on available processor cores.
  static int get defaultConcurrency {
    try {
      return Platform.numberOfProcessors.clamp(2, 8);
    } catch (_) {
      return 2;
    }
  }

  /// Calculates clamped worker count (between 2 and 8).
  static int calculateWorkerCount([int? processors]) {
    final count = processors ?? defaultConcurrency;
    return count.clamp(2, 8);
  }

  final int concurrency;
  final NspGenerationTask? _customGenerator;
  final FileSaverTask? _customFileSaver;
  final NspRegistrationTask? _customNetworkRegistrar;
  final HistoryRecorderTask? _customHistoryRecorder;

  final StreamController<BatchProgressUpdate> _progressController =
      StreamController<BatchProgressUpdate>.broadcast();

  Stream<BatchProgressUpdate> get progressStream => _progressController.stream;

  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  BatchProcessorService({
    int? concurrency,
    NspGenerationTask? customGenerator,
    FileSaverTask? customFileSaver,
    NspRegistrationTask? networkRegistrar,
    HistoryRecorderTask? customHistoryRecorder,
  })  : concurrency = calculateWorkerCount(concurrency),
        _customGenerator = customGenerator,
        _customFileSaver = customFileSaver,
        _customNetworkRegistrar = networkRegistrar,
        _customHistoryRecorder = customHistoryRecorder;

  /// Signals cancellation to all active and queued batch operations.
  void cancel() {
    _isCancelled = true;
  }

  /// Closes the progress stream controller.
  void dispose() {
    _progressController.close();
  }

  void _registerNsp(String filename, String filePath) {
    if (_customNetworkRegistrar != null) {
      _customNetworkRegistrar!(filename, filePath);
    } else {
      NetworkInstallService.instance.registerNspFile(filename, filePath);
    }
  }

  /// Processes [configs] concurrently across a pool of parallel workers.
  Future<BatchResult> processBatch({
    required List<ForwarderConfig> configs,
    required ProdKeys keys,
    String? targetDir,
    void Function(BatchProgressUpdate update)? onProgress,
    int? workerCount,
  }) async {
    if (_isRunning) {
      throw StateError('BatchProcessorService is already running a batch.');
    }

    _isRunning = true;
    _isCancelled = false;

    final activeWorkerPoolSize = (workerCount ?? concurrency).clamp(1, 8);
    final List<BatchItemProgress> items = List.generate(
      configs.length,
      (index) => BatchItemProgress(
        index: index,
        config: configs[index],
        status: BatchItemStatus.queued,
      ),
    );

    final stopwatch = Stopwatch()..start();
    int completedCount = 0;
    int failedCount = 0;
    int cancelledCount = 0;
    int inProgressCount = 0;
    String currentItemTitle = '';

    void emitUpdate({bool isCompleted = false}) {
      final double percentage = configs.isEmpty
          ? 1.0
          : ((completedCount + failedCount + cancelledCount) / configs.length)
              .clamp(0.0, 1.0);

      final update = BatchProgressUpdate(
        totalCount: configs.length,
        completedCount: completedCount,
        failedCount: failedCount,
        cancelledCount: cancelledCount,
        inProgressCount: inProgressCount,
        percentage: percentage,
        elapsedTime: stopwatch.elapsed,
        currentItemTitle: currentItemTitle,
        activeWorkers: inProgressCount,
        isCancelled: _isCancelled,
        isCompleted: isCompleted,
        items: List.unmodifiable(items),
      );

      if (!_progressController.isClosed) {
        _progressController.add(update);
      }
      if (onProgress != null) {
        onProgress(update);
      }
    }

    // Initial queued event
    emitUpdate();

    if (configs.isEmpty) {
      stopwatch.stop();
      _isRunning = false;
      emitUpdate(isCompleted: true);
      return BatchResult(
        items: items,
        completedCount: 0,
        failedCount: 0,
        cancelledCount: 0,
        totalDuration: stopwatch.elapsed,
        isCancelled: false,
      );
    }

    final Queue<int> workQueue = Queue<int>.from(
      List.generate(configs.length, (i) => i),
    );

    Future<void> runWorker() async {
      while (true) {
        if (_isCancelled) break;
        if (workQueue.isEmpty) break;

        final int index = workQueue.removeFirst();
        final config = configs[index];

        items[index] =
            items[index].copyWith(status: BatchItemStatus.processing);
        inProgressCount++;
        currentItemTitle = config.title;
        emitUpdate();

        try {
          if (_isCancelled) {
            items[index] = items[index].copyWith(
              status: BatchItemStatus.cancelled,
              error: 'Batch processing cancelled by user',
            );
            cancelledCount++;
            inProgressCount--;
            emitUpdate();
            break;
          }

          // Execute NSP generation inside background worker Isolate
          GeneratedNspResult result;
          if (_customGenerator != null) {
            result = await _customGenerator!(config: config, keys: keys);
          } else {
            result = await NspGenerator.generateNspAsync(
              config: config,
              keys: keys,
            );
          }

          if (_isCancelled) {
            items[index] = items[index].copyWith(
              status: BatchItemStatus.cancelled,
              error: 'Batch processing cancelled by user',
            );
            cancelledCount++;
            inProgressCount--;
            emitUpdate();
            break;
          }

          // Save generated NSP file
          String? savedPath;
          if (_customFileSaver != null) {
            savedPath = await _customFileSaver!(
              result.filename,
              result.nspBytes,
              targetDir: targetDir,
            );
          } else {
            savedPath = await FileSaverService.saveNspFile(
              result.filename,
              result.nspBytes,
              targetDir: targetDir,
            );
          }

          if (savedPath == null) {
            throw Exception('Could not write NSP file to storage destination.');
          }

          // Register the on-disk NSP for wireless installation instead of
          // keeping the full byte array in memory.
          _registerNsp(result.filename, savedPath);

          // Add to preset history
          try {
            if (_customHistoryRecorder != null) {
              await _customHistoryRecorder!(config);
            } else {
              await SavedPresetService.addToHistory(config);
            }
          } catch (_) {}

          items[index] = items[index].copyWith(
            status: BatchItemStatus.completed,
            outputPath: savedPath,
          );
          completedCount++;
          inProgressCount--;
          emitUpdate();
        } catch (e) {
          items[index] = items[index].copyWith(
            status: BatchItemStatus.failed,
            error: e.toString(),
          );
          failedCount++;
          inProgressCount--;
          emitUpdate();
        }
      }
    }

    final actualWorkers = activeWorkerPoolSize.clamp(1, configs.length);
    final workerFutures = List.generate(actualWorkers, (_) => runWorker());
    await Future.wait(workerFutures);

    // If cancelled, mark any items remaining in workQueue as cancelled
    if (_isCancelled) {
      while (workQueue.isNotEmpty) {
        final remainingIdx = workQueue.removeFirst();
        items[remainingIdx] = items[remainingIdx].copyWith(
          status: BatchItemStatus.cancelled,
          error: 'Batch processing cancelled before starting',
        );
        cancelledCount++;
      }
    }

    stopwatch.stop();
    _isRunning = false;
    emitUpdate(isCompleted: true);

    return BatchResult(
      items: items,
      completedCount: completedCount,
      failedCount: failedCount,
      cancelledCount: cancelledCount,
      totalDuration: stopwatch.elapsed,
      isCancelled: _isCancelled,
    );
  }
}
