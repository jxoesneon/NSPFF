import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/forwarder_config.dart';
import '../models/retroarch_core.dart';
import '../services/autodetect_inference_service.dart';
import '../services/boxart_downloader_service.dart';
import '../services/file_saver_service.dart';
import '../services/keys_service.dart';
import '../services/network_install_service.dart';
import '../services/nsp_generator.dart';
import '../services/preset_service.dart';
import '../theme/switch_gamepad_navigation.dart';
import '../theme/switch_theme.dart';
import '../widgets/icon_preview_picker.dart';
import '../widgets/network_install_dialog.dart';
import '../widgets/switch_button.dart';
import '../widgets/switch_card.dart';
import '../widgets/switch_dropdown.dart';
import '../widgets/switch_text_field.dart';
import '../widgets/switch_toggle.dart';
import '../widgets/title_id_input.dart';

class RetroArchForwarderScreen extends StatefulWidget {
  const RetroArchForwarderScreen({super.key});

  @override
  State<RetroArchForwarderScreen> createState() =>
      _RetroArchForwarderScreenState();
}

class _RetroArchForwarderScreenState extends State<RetroArchForwarderScreen> {
  RetroArchCore? _selectedCore =
      RetroArchCore.builtInCores.firstWhere((c) => c.id == 'snes9x');

  late final TextEditingController _corePathController;
  final _romPathController =
      TextEditingController(text: '/roms/snes/Super Mario World.sfc');
  final _titleController = TextEditingController(text: 'Super Mario World');
  final _publisherController = TextEditingController(text: 'SNES / RetroArch');
  final _versionController = TextEditingController(text: '1.0.0');
  final _idController =
      TextEditingController(text: TitleIdInput.generateRandomID());

  Uint8List? _iconBytes;
  bool _startupUserAccount = true;
  bool _screenshot = true;
  bool _videoCapture = true;
  bool _enableSvcDebug = false;
  LogoType _logoType = LogoType.nintendo;
  bool _showAdvanced = false;
  bool _isGenerating = false;
  bool _isSuccess = false;

  bool get _canGenerateNsp =>
      _titleController.text.trim().isNotEmpty &&
      _corePathController.text.trim().isNotEmpty &&
      _romPathController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _corePathController =
        TextEditingController(text: _selectedCore?.defaultPath ?? '');
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
        if (_publisherController.text.isEmpty ||
            _publisherController.text.contains('RetroArch')) {
          _publisherController.text = '${newCore.systemName} / RetroArch';
        }
      });
    }
  }

  Future<void> _runSmartAutodetect() async {
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

    // Auto-fetch Boxart if system matches
    if (_selectedCore != null) {
      final boxartBytes = await BoxartDownloaderService.fetchBoxartImage(
          _selectedCore!.systemName, result.title);
      if (boxartBytes != null && mounted) {
        final resized = await resizeIconBytes(boxartBytes);
        if (mounted) {
          setState(() {
            _iconBytes = resized;
          });
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('⚡ Auto-detected core, title, paths & fetched HD boxart!'),
          backgroundColor: AppTheme.switchGreen,
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
      await _runSmartAutodetect();
    }
  }

  void _onRomPathChanged(String romPath) {
    if (romPath.trim().isNotEmpty) {
      unawaited(_runSmartAutodetect());
    }
    setState(() {});
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

    final keys = context.read<KeysService>().currentKeys;
    if (keys == null || !keys.isValid) {
      _showError(
          'Valid prod.keys required! Please configure keys in Keys Manager.');
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

      final result =
          await NspGenerator.generateNspAsync(config: config, keys: keys);
      final savedPath = await FileSaverService.saveToDownloads(
          result.filename, result.nspBytes);
      await SavedPresetService.addToHistory(config);

      // Register for direct wireless installation
      NetworkInstallService.instance
          .registerNsp(result.filename, result.nspBytes);

      if (mounted) {
        setState(() {
          _isSuccess = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isSuccess = false);
        });

        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            title: const Row(
              children: [
                Icon(Icons.sports_esports,
                    color: AppTheme.switchCyan, size: 28),
                SizedBox(width: 10),
                Text('RetroArch NSP Ready!',
                    style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppTheme.switchCyan, width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black45,
                              blurRadius: 8,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _iconBytes != null
                            ? Image.memory(
                                _iconBytes!,
                                fit: BoxFit.cover,
                                cacheWidth: 256,
                                cacheHeight: 256,
                              )
                            : Container(
                                color: AppTheme.inputBackground,
                                child: const Icon(Icons.sports_esports,
                                    size: 60, color: AppTheme.switchCyan),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _titleController.text.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.cardBorder),
                  const SizedBox(height: 12),
                  _buildDetailRow('Saved to', savedPath,
                      color: AppTheme.switchGreen, isBold: true),
                  _buildDetailRow('Filename', result.filename),
                  _buildDetailRow('Title ID', result.titleId,
                      color: AppTheme.switchCyan, isMono: true),
                  _buildDetailRow(
                      'Core', _selectedCore?.displayName ?? 'RetroArch'),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.wifi_tethering,
                    color: AppTheme.switchCyan, size: 18),
                label: const Text(
                  'WIRELESS INSTALL',
                  style: TextStyle(
                    color: AppTheme.switchCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  NetworkInstallDialog.show(context,
                      targetFilename: result.filename);
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
      }
    } catch (e) {
      _showError('Generation failed: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Widget _buildDetailRow(String label, String value,
      {Color? color, bool isBold = false, bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            value,
            style: isMono
                ? AppTheme.monoStyle(
                    color: color ?? AppTheme.textSecondary, fontSize: 12)
                : TextStyle(
                    color: color ?? AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  ),
          ),
        ],
      ),
    );
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
        GamepadStartIntent: GamepadStartAction(onStart: _generateNsp),
        GamepadQuickActionIntent:
            GamepadQuickAction(onQuickAction: _runSmartAutodetect),
        GamepadBrowseIntent: GamepadBrowseAction(onBrowse: _pickRomFile),
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // Header Card
                SwitchCard(
                  title: 'RetroArch ROM Forwarder',
                  subtitle:
                      'Direct home-screen shortcuts for RetroArch emulator cores & ROMs',
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
                                foregroundColor: AppTheme.switchCyan,
                                side: const BorderSide(
                                    color: AppTheme.switchCyan),
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
                                backgroundColor: AppTheme.switchCyan,
                                foregroundColor: Colors.black,
                              ),
                              icon: const Icon(Icons.bolt, size: 18),
                              label: const Text('Smart Auto-Fill',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
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
                        onChanged: (v) {
                          _onRomPathChanged(v);
                        },
                        tooltip:
                            'Exact path to the ROM file on the Nintendo Switch SD card.',
                      ),
                      SwitchTextField(
                        label: 'RetroArch Core NRO Path',
                        hint: '/retroarch/cores/snes9x_libretro_libswitch.nro',
                        controller: _corePathController,
                        isPath: true,
                        prefixIcon: Icons.memory,
                        tooltip: 'Path to the libretro core .nro on SD card.',
                        onChanged: (v) => setState(() {}),
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
                        onChanged: (v) => setState(() {}),
                      ),
                      SwitchTextField(
                        label: 'Publisher / System',
                        hint: 'SNES / RetroArch',
                        controller: _publisherController,
                        prefixIcon: Icons.business,
                        onChanged: (v) => setState(() {}),
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
                        onImageSelected: (bytes) =>
                            setState(() => _iconBytes = bytes),
                      ),
                    ],
                  ),
                ),

                // Advanced Options Accordion
                SwitchCard(
                  title: 'Advanced Options',
                  trailing: IconButton(
                    icon: Icon(
                      _showAdvanced
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.switchCyan,
                    ),
                    onPressed: () =>
                        setState(() => _showAdvanced = !_showAdvanced),
                  ),
                  child: _showAdvanced
                      ? Column(
                          children: [
                            SwitchToggle(
                              title: 'Startup User Account Selection',
                              subtitle:
                                  'Prompts for Switch profile selection when launching game',
                              value: _startupUserAccount,
                              onChanged: (v) =>
                                  setState(() => _startupUserAccount = v),
                            ),
                            SwitchToggle(
                              title: 'Enable Screenshots',
                              subtitle:
                                  'Capture gameplay screenshots with Joy-Con',
                              value: _screenshot,
                              onChanged: (v) => setState(() => _screenshot = v),
                            ),
                            SwitchToggle(
                              title: 'Enable Video Capture',
                              subtitle: 'Record 30-second gameplay clips',
                              value: _videoCapture,
                              onChanged: (v) =>
                                  setState(() => _videoCapture = v),
                            ),
                            SwitchToggle(
                              title: 'Enable SVC Debug',
                              subtitle: 'System Call Debug permissions',
                              value: _enableSvcDebug,
                              onChanged: (v) =>
                                  setState(() => _enableSvcDebug = v),
                            ),
                            const SizedBox(height: 8),
                            LogoTypeDropdown(
                              selectedLogo: _logoType,
                              onChanged: (val) =>
                                  setState(() => _logoType = val),
                            ),
                          ],
                        )
                      : const Text(
                          'Tap arrow to configure user prompt, captures & startup logos',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                ),

                const SizedBox(height: 12),
                SwitchButton(
                  text: 'GENERATE RETROARCH NSP',
                  icon: Icons.add_circle_outline,
                  successIcon: Icons.check_circle,
                  isSuccess: _isSuccess,
                  variant: SwitchButtonVariant.success,
                  isLoading: _isGenerating,
                  onPressed: _canGenerateNsp ? _generateNsp : null,
                ),
                const SizedBox(height: 8),
                SwitchButton(
                  text: 'WIRELESS INSTALL',
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
    );
  }
}
