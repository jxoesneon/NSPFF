import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/prod_keys.dart';
import '../services/keys_service.dart';
import '../theme/switch_theme.dart';
import '../widgets/switch_button.dart';
import '../widgets/switch_card.dart';

class KeysManagerScreen extends StatefulWidget {
  const KeysManagerScreen({Key? key}) : super(key: key);

  @override
  State<KeysManagerScreen> createState() => _KeysManagerScreenState();
}

class _KeysManagerScreenState extends State<KeysManagerScreen> {
  final _keysTextController = TextEditingController();
  ProdKeys? _parsedKeys;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedKeys();
  }

  Future<void> _loadSavedKeys() async {
    setState(() => _isLoading = true);
    final keys = await KeysService.loadKeys();
    if (keys != null) {
      setState(() {
        _parsedKeys = keys;
        _keysTextController.text = keys.rawText;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickKeysFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.bytes != null) {
      final text = String.fromCharCodes(result.files.single.bytes!);
      setState(() {
        _keysTextController.text = text;
        _parsedKeys = ProdKeys.parse(text);
      });
      await KeysService.saveKeys(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('prod.keys file imported successfully!'),
            backgroundColor: SwitchTheme.switchGreen,
          ),
        );
      }
    }
  }

  Future<void> _saveRawText() async {
    final text = _keysTextController.text;
    final keys = ProdKeys.parse(text);
    setState(() => _parsedKeys = keys);
    await KeysService.saveKeys(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('prod.keys updated!'),
          backgroundColor: SwitchTheme.switchGreen,
        ),
      );
    }
  }

  Future<void> _clearKeys() async {
    await KeysService.clearKeys();
    setState(() {
      _keysTextController.clear();
      _parsedKeys = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keys cleared.'),
          backgroundColor: SwitchTheme.switchRed,
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
          Text(label, style: const TextStyle(color: SwitchTheme.textSecondary, fontSize: 13)),
          Row(
            children: [
              Icon(
                isPresent ? Icons.check_circle : Icons.cancel,
                color: isPresent ? SwitchTheme.switchGreen : SwitchTheme.switchRed,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isPresent ? 'PRESENT' : 'MISSING',
                style: TextStyle(
                  color: isPresent ? SwitchTheme.switchGreen : SwitchTheme.switchRed,
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
        child: CircularProgressIndicator(color: SwitchTheme.switchCyan),
      );
    }

    final bool hasKeys = _parsedKeys != null && _parsedKeys!.isValid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status Overview Card
          SwitchCard(
            title: 'Key Diagnostics & Status',
            borderColor: hasKeys ? SwitchTheme.switchGreen : SwitchTheme.switchRed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasKeys ? Icons.verified : Icons.error_outline,
                      color: hasKeys ? SwitchTheme.switchGreen : SwitchTheme.switchRed,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasKeys ? 'Keys Configured & Ready' : 'Keys Missing or Incomplete',
                            style: TextStyle(
                              color: hasKeys ? SwitchTheme.switchGreen : SwitchTheme.switchRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            hasKeys
                                ? '${_parsedKeys!.keysMap.length} cryptographic keys loaded'
                                : 'Import prod.keys to enable NSP building & NCA signing',
                            style: const TextStyle(color: SwitchTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: SwitchTheme.cardBorder),
                const SizedBox(height: 8),
                _buildKeyStatusRow('header_key', _parsedKeys?.hasHeaderKey ?? false),
                _buildKeyStatusRow('sd_seed', _parsedKeys?.hasSdSeed ?? false),
                _buildKeyStatusRow('titlekdk_00', _parsedKeys?.hasTitleKdk ?? false),
                _buildKeyStatusRow('key_area_key_application', _parsedKeys?.hasKeyAreaKey ?? false),
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
                    foregroundColor: SwitchTheme.switchCyan,
                    side: const BorderSide(color: SwitchTheme.switchCyan),
                  ),
                  icon: const Icon(Icons.file_open, size: 18),
                  label: const Text('Browse & Import prod.keys File'),
                  onPressed: _pickKeysFile,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Raw Keys File Editor',
                  style: TextStyle(color: SwitchTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _keysTextController,
                  maxLines: 8,
                  style: const TextStyle(color: SwitchTheme.textPrimary, fontSize: 12, fontFamily: 'Monospace'),
                  decoration: const InputDecoration(
                    hintText: 'header_key = ...\nsd_seed = ...\ntitlekdk_00 = ...',
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
