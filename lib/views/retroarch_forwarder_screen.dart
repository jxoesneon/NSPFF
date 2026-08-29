import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
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
import '../widgets/icon_preview_picker.dart';
import '../widgets/switch_button.dart';
import '../widgets/switch_card.dart';
import '../widgets/switch_dropdown.dart';
import '../widgets/switch_text_field.dart';
import '../widgets/switch_toggle.dart';
import '../widgets/title_id_input.dart';

class RetroArchForwarderScreen extends StatefulWidget {
  const RetroArchForwarderScreen({Key? key}) : super(key: key);

  @override
  State<RetroArchForwarderScreen> createState() => _RetroArchForwarderScreenState();
}

class _RetroArchForwarderScreenState extends State<RetroArchForwarderScreen> {
  RetroArchCore? _selectedCore = RetroArchCore.builtInCores.firstWhere((c) => c.id == 'snes9x');
  
  late final TextEditingController _corePathController;
  final _romPathController = TextEditingController(text: '/roms/snes/Super Mario World.sfc');
  final _titleController = TextEditingController(text: 'Super Mario World');
  final _publisherController = TextEditingController(text: 'SNES / RetroArch');
  final _versionController = TextEditingController(text: '1.0.0');
  final _idController = TextEditingController(text: TitleIdInput.generateRandomID());

  Uint8List? _iconBytes;
  bool _startupUserAccount = true;
  bool _screenshot = true;
  bool _videoCapture = true;
  bool _enableSvcDebug = false;
  LogoType _logoType = LogoType.nintendo;
  bool _showAdvanced = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _corePathController = TextEditingController(text: _selectedCore?.defaultPath ?? '');
  }

  @override
  void dispose() {
    _corePathController.dispose();
    _romPathController.dispose();
    _titleController.dispose();
    _publisherController.dispose();
    _versionController.dispose();
    _idController.dispose();
    super.dispose();
  }

  void _onCoreChanged(RetroArchCore? newCore) {
    if (newCore != null) {
      setState(() {
        _selectedCore = newCore;
        _corePathController.text = newCore.defaultPath;
        if (_publisherController.text.isEmpty || _publisherController.text.contains('RetroArch')) {
          _publisherController.text = '${newCore.systemName} / RetroArch';
        }
      });
    }
  }

  void _runSmartAutodetect() {
    final input = _romPathController.text.trim();
    if (input.isEmpty) return;

    final result = AutodetectInferenceService.inferRomDetails(input);
    setState(() {
      _titleController.text = result.title;
      _publisherController.text = result.publisher;
      if (result.core != null) {
        _selectedCore = result.core;
      }
      _corePathController.text = result.corePath;
      _romPathController.text = result.romSdPath;
      _idController.text = result.titleId;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Auto-detected core, game title, and SD paths!'),
          backgroundColor: SwitchTheme.switchGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickRomFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.name.isNotEmpty) {
      _romPathController.text = result.files.single.name;
      _runSmartAutodetect();
    }
  }

  void _onRomPathChanged(String romPath) {
    if (romPath.trim().isNotEmpty) {
      _runSmartAutodetect();
    }
  }

  Future<void> _generateNsp() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Game Title is required');
      return;
    }
    if (_corePathController.text.trim().isEmpty) {
      _showError('RetroArch Core NRO path is required');
      return;
    }
    if (_romPathController.text.trim().isEmpty) {
      _showError('Target ROM path on SD card is required');
      return;
    }

    final keys = await KeysService.loadKeys();
    if (keys == null || !keys.isValid) {
      _showError('Valid prod.keys required! Please configure keys in Keys Manager.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final config = ForwarderConfig(
        id: _idController.text.trim(),
        title: _titleController.text.trim(),
        publisher: _publisherController.text.trim(),
        version: _versionController.text.trim(),
        nroPath: _corePathController.text.trim(),
        romPath: _romPathController.text.trim(),
        isRetroArch: true,
        selectedCore: _selectedCore,
        imageBytes: _iconBytes,
        startupUserAccount: _startupUserAccount,
        screenshot: _screenshot,
        videoCapture: _videoCapture,
        enableSvcDebug: _enableSvcDebug,
        logoType: _logoType,
      );

      final result = await NspGenerator.generateNsp(config: config, keys: keys);
      await SavedPresetService.addToHistory(config);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: SwitchTheme.cardBackground,
            title: const Row(
              children: [
                Icon(Icons.sports_esports, color: SwitchTheme.switchCyan, size: 28),
                SizedBox(width: 10),
                Text('RetroArch NSP Ready!', style: TextStyle(color: SwitchTheme.textPrimary)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filename: ${result.filename}', style: const TextStyle(color: SwitchTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                Text('Title ID: ${result.titleId}', style: const TextStyle(color: SwitchTheme.switchCyan, fontFamily: 'Monospace', fontSize: 13)),
                const SizedBox(height: 6),
                Text('Core: ${_selectedCore?.displayName}', style: const TextStyle(color: SwitchTheme.textMuted, fontSize: 12)),
              ],
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
      _showError('Generation failed: $e');
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
          // Header Card
          SwitchCard(
            title: 'RetroArch ROM Forwarder',
            subtitle: 'Direct home-screen shortcuts for RetroArch emulator cores & ROMs',
            child: RetroArchCoreDropdown(
              selectedCore: _selectedCore,
              onChanged: _onCoreChanged,
            ),
          ),

          // ROM & Path Config
          SwitchCard(
            title: 'ROM & Target Paths',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SwitchTheme.switchCyan,
                          side: const BorderSide(color: SwitchTheme.switchCyan),
                        ),
                        icon: const Icon(Icons.file_open, size: 16),
                        label: const Text('Browse ROM File'),
                        onPressed: _pickRomFile,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SwitchTheme.switchCyan,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.bolt, size: 18),
                        label: const Text('Smart Auto-Fill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: _runSmartAutodetect,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchTextField(
                  label: 'Target ROM Path on SD Card',
                  hint: '/roms/snes/Super Mario World.sfc',
                  controller: _romPathController,
                  isPath: true,
                  prefixIcon: Icons.videogame_asset,
                  onChanged: _onRomPathChanged,
                  helperText: 'Exact path to your ROM file on the Nintendo Switch SD card.',
                ),
                SwitchTextField(
                  label: 'RetroArch Core NRO Path',
                  hint: '/retroarch/cores/snes9x_libretro_libswitch.nro',
                  controller: _corePathController,
                  isPath: true,
                  prefixIcon: Icons.memory,
                  helperText: 'Path to the libretro core .nro on SD card.',
                ),
              ],
            ),
          ),

          // Display Details Card
          SwitchCard(
            title: 'Display & Boxart',
            child: Column(
              children: [
                SwitchTextField(
                  label: 'Game Title',
                  hint: 'Super Mario World',
                  controller: _titleController,
                  prefixIcon: Icons.title,
                ),
                SwitchTextField(
                  label: 'Publisher / System',
                  hint: 'SNES / RetroArch',
                  controller: _publisherController,
                  prefixIcon: Icons.business,
                ),
                SwitchTextField(
                  label: 'Version',
                  hint: '1.0.0',
                  controller: _versionController,
                  prefixIcon: Icons.label_outline,
                ),
                TitleIdInput(
                  controller: _idController,
                ),
                IconPreviewPicker(
                  imageBytes: _iconBytes,
                  onImageSelected: (bytes) => setState(() => _iconBytes = bytes),
                ),
              ],
            ),
          ),

          // Advanced Options Accordion
          SwitchCard(
            title: 'Advanced Options (1:1 Parity)',
            trailing: IconButton(
              icon: Icon(
                _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: SwitchTheme.switchCyan,
              ),
              onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
            ),
            child: _showAdvanced
                ? Column(
                    children: [
                      SwitchToggle(
                        title: 'Startup User Account Selection',
                        subtitle: 'Prompts for Switch profile selection when launching game',
                        value: _startupUserAccount,
                        onChanged: (v) => setState(() => _startupUserAccount = v),
                      ),
                      SwitchToggle(
                        title: 'Enable Screenshots',
                        subtitle: 'Capture gameplay screenshots with Joy-Con',
                        value: _screenshot,
                        onChanged: (v) => setState(() => _screenshot = v),
                      ),
                      SwitchToggle(
                        title: 'Enable Video Capture',
                        subtitle: 'Record 30-second gameplay clips',
                        value: _videoCapture,
                        onChanged: (v) => setState(() => _videoCapture = v),
                      ),
                      SwitchToggle(
                        title: 'Enable SVC Debug',
                        subtitle: 'System Call Debug permissions',
                        value: _enableSvcDebug,
                        onChanged: (v) => setState(() => _enableSvcDebug = v),
                      ),
                      const SizedBox(height: 8),
                      LogoTypeDropdown(
                        selectedLogo: _logoType,
                        onChanged: (val) => setState(() => _logoType = val),
                      ),
                    ],
                  )
                : const Text(
                    'Tap arrow to configure user prompt, captures & startup logos',
                    style: TextStyle(color: SwitchTheme.textMuted, fontSize: 12),
                  ),
          ),

          const SizedBox(height: 12),
          SwitchButton(
            text: 'GENERATE RETROARCH NSP',
            icon: Icons.sports_esports,
            variant: SwitchButtonVariant.primary,
            isLoading: _isGenerating,
            onPressed: _generateNsp,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
