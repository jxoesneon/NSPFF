import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/keys_service.dart';
import '../theme/switch_theme.dart';
import '../widgets/switch_button.dart';
import '../widgets/switch_card.dart';

class KeysManagerScreen extends StatefulWidget {
  const KeysManagerScreen({super.key});

  @override
  State<KeysManagerScreen> createState() => _KeysManagerScreenState();
}

class _KeysManagerScreenState extends State<KeysManagerScreen> {
  final _keysTextController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedKeys();
  }

  @override
  void dispose() {
    _keysTextController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedKeys() async {
    setState(() => _isLoading = true);
    final keysService = context.read<KeysService>();
    if (keysService.currentKeys != null) {
      final raw = await KeysService.loadRawText();
      if (raw != null) {
        _keysTextController.text = raw;
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickKeysFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null) {
      final file = result.files.single;
      String? text;
      try {
        if (file.bytes != null) {
          text = String.fromCharCodes(file.bytes!);
        } else if (file.path != null) {
          text = await File(file.path!).readAsString();
        }

        final keysText = text;
        if (keysText != null && keysText.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _keysTextController.text = keysText;
          });
          await context.read<KeysService>().saveKeys(keysText);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('prod.keys file imported successfully!'),
                backgroundColor: AppTheme.switchGreen,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to read keys file: $e'),
              backgroundColor: AppTheme.switchRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _tryAutoImport() async {
    const commonPaths = [
      '/sdcard/Download/prod.keys',
      '/storage/emulated/0/Download/prod.keys',
      '/sdcard/switch/prod.keys',
    ];

    for (final path in commonPaths) {
      final file = File(path);
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            if (!mounted) return;
            _keysTextController.text = content;
            await context.read<KeysService>().saveKeys(content);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Auto-imported keys from $path'),
                  backgroundColor: AppTheme.switchGreen,
                ),
              );
            }
            return;
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find prod.keys in common download folders.'),
          backgroundColor: AppTheme.switchYellow,
        ),
      );
    }
  }

  Future<void> _saveRawText() async {
    final text = _keysTextController.text;
    await context.read<KeysService>().saveKeys(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('prod.keys updated!'),
          backgroundColor: AppTheme.switchGreen,
        ),
      );
    }
  }

  Future<void> _clearKeys() async {
    await context.read<KeysService>().clearKeys();
    setState(() {
      _keysTextController.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keys cleared.'),
          backgroundColor: AppTheme.switchRed,
        ),
      );
    }
  }

  Widget _buildKeyStatusRow(String label, bool isPresent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Row(
            children: [
              Icon(
                isPresent ? Icons.check_circle : Icons.warning_amber_rounded,
                color: isPresent ? AppTheme.switchGreen : AppTheme.switchYellow,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isPresent ? 'PRESENT' : 'MISSING',
                style: TextStyle(
                  color:
                      isPresent ? AppTheme.switchGreen : AppTheme.switchYellow,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.switchCyan),
      );
    }

    final keysService = context.watch<KeysService>();
    final parsedKeys = keysService.currentKeys;
    final bool hasKeys = keysService.hasValidKeys;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status Overview Card
          SwitchCard(
            title: 'Key Diagnostics & Status',
            borderColor: hasKeys ? AppTheme.switchGreen : AppTheme.switchYellow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasKeys ? Icons.verified : Icons.error_outline,
                      color: hasKeys
                          ? AppTheme.switchGreen
                          : AppTheme.switchYellow,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasKeys
                                ? 'Keys Configured & Ready'
                                : 'Keys Missing or Incomplete',
                            style: TextStyle(
                              color: hasKeys
                                  ? AppTheme.switchGreen
                                  : AppTheme.switchYellow,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            hasKeys
                                ? '${parsedKeys!.keysMap.length} cryptographic keys loaded'
                                : 'Import prod.keys to enable NSP building & NCA signing',
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.cardBorder),
                const SizedBox(height: 8),
                _buildKeyStatusRow(
                    'header_key', parsedKeys?.hasHeaderKey ?? false),
                _buildKeyStatusRow('sd_seed', parsedKeys?.hasSdSeed ?? false),
                _buildKeyStatusRow(
                    'titlekdk_00 / titlekek_00',
                    (parsedKeys?.hasTitleKdk ?? false) ||
                        (parsedKeys?.hasTitleKek ?? false)),
                _buildKeyStatusRow('key_area_key_application',
                    parsedKeys?.hasKeyAreaKey ?? false),
                if (!hasKeys) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.switchYellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.switchYellow.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.help_outline,
                            color: AppTheme.switchYellow, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Don\'t have keys?',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              Text(
                                'Use Lockpick_RCM on your console to dump prod.keys. See the Guide tab for detailed steps.',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Import & Edit Card
          SwitchCard(
            title: 'Import prod.keys',
            subtitle: 'Select your prod.keys file or paste key content below',
            child: Column(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.switchCyan,
                    side: const BorderSide(color: AppTheme.switchCyan),
                  ),
                  icon: const Icon(Icons.file_open, size: 18),
                  label: const Text('Browse & Import prod.keys File'),
                  onPressed: _pickKeysFile,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _tryAutoImport,
                  icon: const Icon(Icons.auto_fix_normal, size: 16),
                  label: const Text('Auto-Scan Downloads Folder'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Raw Keys File Editor',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _keysTextController,
                  maxLines: 8,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontFamily: 'Monospace'),
                  decoration: const InputDecoration(
                    hintText:
                        'header_key = ...\nsd_seed = ...\ntitlekdk_00 = ...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SwitchButton(
                        text: 'SAVE KEYS',
                        icon: Icons.save,
                        onPressed: _saveRawText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SwitchButton(
                        text: 'CLEAR',
                        icon: Icons.delete_forever,
                        variant: SwitchButtonVariant.secondary,
                        onPressed: _clearKeys,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
