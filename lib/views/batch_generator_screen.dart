// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../models/forwarder_config.dart';
import '../models/retroarch_core.dart';
import '../services/autodetect_inference_service.dart';
import '../services/batch_processor_service.dart';
import '../services/file_saver_service.dart';
import '../services/keys_service.dart';
import '../services/nca_builder.dart';
import '../theme/switch_gamepad_navigation.dart';
import '../theme/switch_theme.dart';
import '../widgets/network_install_dialog.dart';
import '../widgets/switch_button.dart';
import '../widgets/switch_card.dart';
import '../widgets/switch_dropdown.dart';
import '../widgets/switch_text_field.dart';
import '../widgets/title_id_input.dart';

class BatchGeneratorScreen extends StatefulWidget {
  final BatchProcessorService? batchProcessor;

  const BatchGeneratorScreen({super.key, this.batchProcessor});

  @override
  State<BatchGeneratorScreen> createState() => _BatchGeneratorScreenState();
}

class _BatchGeneratorScreenState extends State<BatchGeneratorScreen> {
  RetroArchCore? _selectedCore =
      RetroArchCore.builtInCores.firstWhere((c) => c.id == 'snes9x');
  final _romListController = TextEditingController(
    text:
        '/roms/snes/Super Mario World.sfc\n/roms/snes/Donkey Kong Country.sfc\n/roms/snes/The Legend of Zelda - A Link to the Past.sfc',
  );
  final _baseTitleIdController =
      TextEditingController(text: '0500000000000010');

  bool _isGenerating = false;
  bool _isSuccess = false;

  bool get _canRunBatch => _romListController.text.trim().isNotEmpty;

  BatchProcessorService? _batchProcessor;
  BatchProgressUpdate? _batchProgress;
  int _totalCount = 0;
  String _targetFolderDisplay = 'Default (Public Downloads / Scoped Storage)';

  @override
  void initState() {
    super.initState();
    _refreshTargetFolder();
  }

  Future<void> _refreshTargetFolder() async {
    final folder = await FileSaverService.getDisplayTargetFolder();
    if (mounted) {
      setState(() {
        _targetFolderDisplay = folder;
      });
    }
  }

  Future<void> _pickOutputFolder() async {
    final picked = await FileSaverService.pickTargetFolder();
    if (picked != null && mounted) {
      await _refreshTargetFolder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target folder updated: $picked'),
          backgroundColor: AppTheme.switchGreen,
        ),
      );
    }
  }

  Future<void> _resetOutputFolder() async {
    await FileSaverService.clearSavedTargetFolder();
    if (mounted) {
      await _refreshTargetFolder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Target folder reset to default.'),
          backgroundColor: AppTheme.switchCyan,
        ),
      );
    }
  }

  void _autoFormatBatchList() {
    final lines = _romListController.text.split('\n');
    final List<String> formatted = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        final result = AutodetectInferenceService.inferRomDetails(trimmed);
        formatted.add(result.romSdPath);
      }
    }

    if (formatted.isNotEmpty) {
      setState(() {
        _romListController.text = formatted.join('\n');
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ Auto-formatted batch ROM paths & cleaned titles!'),
            backgroundColor: AppTheme.switchGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickMultiRoms() async {
    final files = await FilePicker.pickFiles(
      type: FileType.any,
    );

    if (files.isNotEmpty) {
      final List<String> newPaths = [];
      for (var file in files) {
        final path = file.path;
        if (path != null) {
          // Attempt to infer a logical SD path if the picked path is local
          final fileName = p.basename(path);
          final inferred = AutodetectInferenceService.inferRomDetails(fileName);
          newPaths.add(inferred.romSdPath);
        }
      }

      if (newPaths.isNotEmpty) {
        final currentText = _romListController.text.trim();
        final separator = currentText.isEmpty ? '' : '\n';
        setState(() {
          _romListController.text =
              '$currentText$separator${newPaths.join('\n')}';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📂 Added ${newPaths.length} ROMs to the batch!'),
              backgroundColor: AppTheme.switchCyan,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _romListController.dispose();
    _baseTitleIdController.dispose();
    _batchProcessor?.cancel();
    _batchProcessor?.dispose();
    super.dispose();
  }

  void _cancelBatch() {
    if (_batchProcessor != null && !_batchProcessor!.isCancelled) {
      _batchProcessor!.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancelling batch operations cleanly...'),
          backgroundColor: AppTheme.switchYellow,
        ),
      );
    }
  }

  Future<void> _runBatchGeneration() async {
    final rawLines = _romListController.text.split('\n');
    final romPaths =
        rawLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    if (romPaths.isEmpty) {
      _showError('Enter at least one ROM path!');
      return;
    }

    final keys = context.read<KeysService>().currentKeys;
    if (keys == null || !keys.isValid) {
      _showError(
          'Valid prod.keys required! Please import keys in Keys Manager.');
      return;
    }

    BigInt baseId;
    try {
      baseId = NcaBuilder.parseTitleId(_baseTitleIdController.text.trim());
    } catch (_) {
      baseId = BigInt.parse('0500000000000010', radix: 16);
    }

    final List<ForwarderConfig> configs = [];
    for (int i = 0; i < romPaths.length; i++) {
      final romPath = SwitchTextField.normalizePath(romPaths[i]);
      final gameTitle = p.basenameWithoutExtension(romPath);
      // Increment by 0x10 per batch entry to preserve the program-index nibble as 0.
      final titleIdHex = (baseId + BigInt.from(i << 4))
          .toRadixString(16)
          .toUpperCase()
          .padLeft(16, '0');

      configs.add(
        ForwarderConfig(
          id: titleIdHex,
          title: gameTitle,
          publisher: '${_selectedCore?.systemName ?? "RetroArch"} Forwarder',
          nroPath: _selectedCore?.defaultPath ??
              '/retroarch/cores/snes9x_libretro_libswitch.nro',
          romPath: romPath,
          isRetroArch: true,
          selectedCore: _selectedCore,
        ),
      );
    }

    final processor = widget.batchProcessor ?? BatchProcessorService();
    _batchProcessor = processor;

    setState(() {
      _isGenerating = true;
      _totalCount = configs.length;
      _batchProgress = null;
    });

    try {
      final result = await processor.processBatch(
        configs: configs,
        keys: keys,
        onProgress: (update) {
          if (mounted) {
            setState(() {
              _batchProgress = update;
            });
          }
        },
      );

      if (!mounted) return;

      if (result.isCancelled) {
        final cancelledMsg = result.cancelledCount > 0
            ? ' (${result.cancelledCount} cancelled)'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Batch cancelled. Completed ${result.completedCount} of ${configs.length} forwarders.$cancelledMsg',
            ),
            backgroundColor: AppTheme.switchYellow,
          ),
        );
      } else if (result.isSuccess) {
        setState(() {
          _isSuccess = true;
        });
        unawaited(
          Future<void>.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isSuccess = false);
          }),
        );

        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            title: const Row(
              children: [
                Icon(Icons.checklist_sharp,
                    color: AppTheme.switchGreen, size: 28),
                SizedBox(width: 10),
                Text('Batch Complete!',
                    style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
            content: Text(
              'Successfully generated ${result.completedCount} NSP forwarders in ${_formatDuration(result.totalDuration)}!',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.wifi_tethering,
                    color: AppTheme.switchCyan, size: 18),
                label: const Text(
                  'WIRELESS INSTALL BATCH',
                  style: TextStyle(
                    color: AppTheme.switchCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  NetworkInstallDialog.show(context);
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        );
      } else {
        _showError(
            'Batch completed with ${result.failedCount} failures out of ${configs.length} items.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Batch generation failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '00:00';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.switchRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        GamepadStartIntent: GamepadStartAction(onStart: _runBatchGeneration),
        GamepadQuickActionIntent:
            GamepadQuickAction(onQuickAction: _autoFormatBatchList),
        GamepadBrowseIntent: GamepadBrowseAction(onBrowse: _pickMultiRoms),
      },
      child: FocusScope(
        autofocus: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  SwitchCard(
                    title: 'Batch ROM Forwarder Generator',
                    subtitle:
                        'Generate multiple NSP shortcuts automatically with sequential Title IDs',
                    child: Column(
                      children: [
                        RetroArchCoreDropdown(
                          selectedCore: _selectedCore,
                          onChanged: (core) =>
                              setState(() => _selectedCore = core),
                        ),
                        const SizedBox(height: 14),
                        SwitchTextField(
                          label: 'ROM Paths List',
                          tooltip:
                              'Enter one ROM path per line on the Nintendo Switch SD card, or use the Pick ROMs button.',
                          controller: _romListController,
                          maxLines: 8,
                          hint: '/roms/snes/Game1.sfc\n/roms/snes/Game2.sfc',
                          onChanged: (v) => setState(() {}),
                          suffixAction: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Clear List',
                                icon: const Icon(Icons.clear_all,
                                    color: AppTheme.textMuted),
                                onPressed: () =>
                                    setState(() => _romListController.clear()),
                              ),
                              IconButton(
                                tooltip: 'Pick ROMs',
                                icon: const Icon(Icons.add_to_photos_outlined,
                                    color: AppTheme.switchCyan),
                                onPressed: _pickMultiRoms,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TitleIdInput(
                          label: 'Base Title ID (Starting)',
                          tooltip:
                              'Initial 16-hex Title ID. Each ROM in the batch will be assigned a sequentially incremented Title ID.',
                          controller: _baseTitleIdController,
                          showBatchPreview: true,
                          onChanged: (val) =>
                              setState(() {}), // Trigger rebuild for preview
                        ),
                      ],
                    ),
                  ),

                  // Output Target Folder Settings Card (Scoped Storage & SAF)
                  SwitchCard(
                    title: 'Export Target Folder',
                    subtitle:
                        'Modern Android Scoped Storage & Storage Access Framework',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.inputBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_outlined,
                                  color: AppTheme.switchCyan, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _targetFolderDisplay,
                                  style: AppTheme.monoStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SwitchButton(
                                text: 'CHOOSE',
                                icon: Icons.folder_open,
                                variant: SwitchButtonVariant.outline,
                                onPressed:
                                    _isGenerating ? null : _pickOutputFolder,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SwitchButton(
                                text: 'RESET',
                                icon: Icons.refresh,
                                variant: SwitchButtonVariant.outline,
                                onPressed:
                                    _isGenerating ? null : _resetOutputFolder,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_isGenerating) ...[
                    SwitchCard(
                      title:
                          _batchProgress != null && _batchProgress!.isCancelled
                              ? 'Cancelling Batch...'
                              : 'Processing Parallel Batch...',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: _batchProgress?.percentage ??
                                (_totalCount > 0
                                    ? (_batchProgress?.completedCount ?? 0) /
                                        _totalCount
                                    : 0),
                            backgroundColor: AppTheme.inputBackground,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _batchProgress != null &&
                                      _batchProgress!.isCancelled
                                  ? AppTheme.switchYellow
                                  : AppTheme.switchCyan,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Live count: e.g. "Completed 14/50 - 4 parallel workers"
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Completed ${_batchProgress?.completedCount ?? 0}/$_totalCount - ${_batchProcessor?.concurrency ?? BatchProcessorService.defaultConcurrency} parallel workers',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _formatDuration(_batchProgress?.elapsedTime),
                                style: AppTheme.monoStyle(
                                  color: AppTheme.switchCyan,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (_batchProgress != null &&
                              _batchProgress!.cancelledCount > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Cancelled: ${_batchProgress!.cancelledCount}',
                              style: const TextStyle(
                                color: AppTheme.switchYellow,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (_batchProgress != null &&
                              _batchProgress!.currentItemTitle.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Processing: ${_batchProgress!.currentItemTitle}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 12),
                          SwitchButton(
                            text: 'CANCEL BATCH',
                            icon: Icons.cancel,
                            variant: SwitchButtonVariant.secondary,
                            onPressed: _cancelBatch,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  // Utility Buttons Row (Secondary Style, Reachable)
                  Row(
                    children: [
                      Expanded(
                        child: SwitchButton(
                          text: 'PICK ROMS',
                          icon: Icons.file_open,
                          variant: SwitchButtonVariant.outline,
                          onPressed: _isGenerating ? null : _pickMultiRoms,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchButton(
                          text: 'AUTO-FORMAT',
                          icon: Icons.auto_fix_high,
                          variant: SwitchButtonVariant.outline,
                          onPressed:
                              _isGenerating ? null : _autoFormatBatchList,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchButton(
                    text: 'RUN BATCH GENERATION',
                    icon: Icons.add_circle_outline,
                    successIcon: Icons.playlist_add_check,
                    isSuccess: _isSuccess,
                    variant: SwitchButtonVariant.success,
                    isLoading: _isGenerating,
                    onPressed: _canRunBatch ? _runBatchGeneration : null,
                  ),
                  const SizedBox(height: 8),
                  SwitchButton(
                    text: 'WIRELESS INSTALL BATCH',
                    icon: Icons.wifi_tethering,
                    variant: SwitchButtonVariant.outline,
                    onPressed: () => NetworkInstallDialog.show(context),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
