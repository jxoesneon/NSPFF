import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/forwarder_config.dart';
import '../models/retroarch_core.dart';
import '../models/prod_keys.dart';
import '../services/autodetect_inference_service.dart';
import '../services/keys_service.dart';
import '../services/nsp_generator.dart';
import '../services/preset_service.dart';
import '../theme/switch_theme.dart';
import '../widgets/switch_button.dart';
import '../widgets/switch_card.dart';
import '../widgets/switch_dropdown.dart';
import '../widgets/switch_text_field.dart';
import '../widgets/title_id_input.dart';

class BatchGeneratorScreen extends StatefulWidget {
  const BatchGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<BatchGeneratorScreen> createState() => _BatchGeneratorScreenState();
}

class _BatchGeneratorScreenState extends State<BatchGeneratorScreen> {
  RetroArchCore? _selectedCore = RetroArchCore.builtInCores.firstWhere((c) => c.id == 'snes9x');
  final _romListController = TextEditingController(
    text: '/roms/snes/Super Mario World.sfc\n/roms/snes/Donkey Kong Country.sfc\n/roms/snes/The Legend of Zelda - A Link to the Past.sfc',
  );
  final _baseTitleIdController = TextEditingController(text: '0500000000000010');

  bool _isGenerating = false;

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
            backgroundColor: SwitchTheme.switchGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
  int _generatedCount = 0;
  int _totalCount = 0;

  @override
  void dispose() {
    _romListController.dispose();
    _baseTitleIdController.dispose();
    super.dispose();
  }

  Future<void> _runBatchGeneration() async {
    final rawLines = _romListController.text.split('\n');
    final romPaths = rawLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    if (romPaths.isEmpty) {
      _showError('Enter at least one ROM path!');
      return;
    }

    final keys = await KeysService.loadKeys();
    if (keys == null || !keys.isValid) {
      _showError('Valid prod.keys required! Please import keys in Keys Manager.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedCount = 0;
      _totalCount = romPaths.length;
    });

    BigInt baseId;
    try {
      baseId = BigInt.parse(_baseTitleIdController.text.trim(), radix: 16);
    } catch (_) {
      baseId = BigInt.parse('0500000000000010', radix: 16);
    }

    try {
      for (int i = 0; i < romPaths.length; i++) {
        final romPath = SwitchTextField.normalizePath(romPaths[i]);
        final gameTitle = p.basenameWithoutExtension(romPath);
        final titleIdHex = (baseId + BigInt.from(i)).toRadixString(16).toUpperCase().padLeft(16, '0');

        final config = ForwarderConfig(
          id: titleIdHex,
          title: gameTitle,
          publisher: '${_selectedCore?.systemName ?? "RetroArch"} Forwarder',
          nroPath: _selectedCore?.defaultPath ?? '/retroarch/cores/snes9x_libretro_libswitch.nro',
          romPath: romPath,
          isRetroArch: true,
          selectedCore: _selectedCore,
        );

        await NspGenerator.generateNsp(config: config, keys: keys);
        await SavedPresetService.addToHistory(config);

        setState(() {
          _generatedCount = i + 1;
        });
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: SwitchTheme.cardBackground,
            title: const Row(
              children: [
                Icon(Icons.checklist_sharp, color: SwitchTheme.switchGreen, size: 28),
                SizedBox(width: 10),
                Text('Batch Complete!', style: TextStyle(color: SwitchTheme.textPrimary)),
              ],
            ),
            content: Text(
              'Successfully generated $_generatedCount NSP forwarders!',
              style: const TextStyle(color: SwitchTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: SwitchTheme.switchCyan)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError('Batch generation failed: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SwitchTheme.switchRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchCard(
            title: 'Batch ROM Forwarder Generator',
            subtitle: 'Generate multiple NSP shortcuts automatically with sequential Title IDs',
            child: Column(
              children: [
                RetroArchCoreDropdown(
                  selectedCore: _selectedCore,
                  onChanged: (core) => setState(() => _selectedCore = core),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwitchTheme.switchCyan,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('Smart Auto-Format List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _autoFormatBatchList,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ROM Paths List (One per line)',
                  style: TextStyle(
                    color: SwitchTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _romListController,
                  maxLines: 6,
                  style: const TextStyle(color: SwitchTheme.textPrimary, fontSize: 13, fontFamily: 'Monospace'),
                  decoration: const InputDecoration(
                    hintText: '/roms/snes/Game1.sfc\n/roms/snes/Game2.sfc',
                  ),
                ),
                const SizedBox(height: 14),
                TitleIdInput(
                  controller: _baseTitleIdController,
                ),
              ],
            ),
          ),

          if (_isGenerating) ...[
            SwitchCard(
              title: 'Generating Batch...',
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _totalCount > 0 ? _generatedCount / _totalCount : 0,
                    backgroundColor: SwitchTheme.inputBackground,
                    valueColor: const AlwaysStoppedAnimation<Color>(SwitchTheme.switchCyan),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_generatedCount / $_totalCount NSPs created',
                    style: const TextStyle(color: SwitchTheme.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          SwitchButton(
            text: 'RUN BATCH GENERATION',
            icon: Icons.dynamic_feed,
            isLoading: _isGenerating,
            onPressed: _runBatchGeneration,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
