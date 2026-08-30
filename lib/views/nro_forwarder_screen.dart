import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/forwarder_config.dart';
import '../services/autodetect_inference_service.dart';
import '../services/file_saver_service.dart';
import '../services/network_install_service.dart';
import '../services/keys_service.dart';
import '../services/nsp_generator.dart';
import '../services/nro_parser.dart';
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

class NroForwarderScreen extends StatefulWidget {
  const NroForwarderScreen({super.key});

  @override
  State<NroForwarderScreen> createState() => _NroForwarderScreenState();
}

class _NroForwarderScreenState extends State<NroForwarderScreen> {
  final _nroPathController = TextEditingController(text: '/switch/hbmenu.nro');
  final _titleController = TextEditingController(text: 'HBMenu');
  final _publisherController = TextEditingController(text: 'Switch Homebrew');
  final _versionController = TextEditingController(text: '1.0.0');
  final _idController =
      TextEditingController(text: TitleIdInput.generateRandomID());

  Uint8List? _iconBytes;
  Uint8List? _logoBytes;
  Uint8List? _startupMovieBytes;

  bool _startupUserAccount = true;
  bool _screenshot = true;
  bool _videoCapture = true;
  bool _enableSvcDebug = false;
  LogoType _logoType = LogoType.nintendo;
  bool _showAdvanced = false;
  bool _isGenerating = false;

  bool get _canGenerateNsp =>
      _titleController.text.trim().isNotEmpty &&
      _publisherController.text.trim().isNotEmpty &&
      _nroPathController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nroPathController.dispose();
    _titleController.dispose();
    _publisherController.dispose();
    _versionController.dispose();
    _idController.dispose();
    super.dispose();
  }

  void _runSmartAutodetect() {
    final input = _nroPathController.text.trim();
    if (input.isEmpty) return;

    final result = AutodetectInferenceService.inferNroDetails(input);
    setState(() {
      _titleController.text = result.title;
      _publisherController.text = result.publisher;
      _nroPathController.text = result.nroSdPath;
      _idController.text = result.titleId;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Auto-detected app title and SD path!'),
          backgroundColor: AppTheme.switchGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _extractNroMetadata() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.bytes != null) {
      final meta = NroParser.parseNro(result.files.single.bytes!);
      if (meta != null) {
        setState(() {
          _titleController.text = meta.title;
          _publisherController.text = meta.author;
          _versionController.text = meta.version;
        });
        if (meta.iconBytes != null) {
          final resized = await resizeIconBytes(meta.iconBytes!);
          if (mounted) {
            setState(() {
              _iconBytes = resized;
            });
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auto-extracted NACP metadata from .nro!'),
              backgroundColor: AppTheme.switchGreen,
            ),
          );
        }
      }
    }
  }

  Future<void> _generateNsp() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Title is required');
      return;
    }
    if (_publisherController.text.trim().isEmpty) {
      _showError('Publisher / Author is required');
      return;
    }
    if (_nroPathController.text.trim().isEmpty) {
      _showError('NRO Path on SD card is required');
      return;
    }

    final keys = await KeysService.loadKeys();
    if (keys == null || !keys.isValid) {
      _showError(
          'Valid prod.keys required! Please configure keys in the Keys Manager tab.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final config = ForwarderConfig(
        id: _idController.text.trim(),
        title: _titleController.text.trim(),
        publisher: _publisherController.text.trim(),
        version: _versionController.text.trim(),
        nroPath: _nroPathController.text.trim(),
        imageBytes: _iconBytes,
        logoBytes: _logoBytes,
        startupMovieBytes: _startupMovieBytes,
        startupUserAccount: _startupUserAccount,
        screenshot: _screenshot,
        videoCapture: _videoCapture,
        enableSvcDebug: _enableSvcDebug,
        logoType: _logoType,
      );

      final result =
          await NspGenerator.generateNspAsync(config: config, keys: keys);
      final savedPath =
          await FileSaverService.saveNspFile(result.filename, result.nspBytes);
      await SavedPresetService.addToHistory(config);

      // Register for direct wireless installation
      NetworkInstallService.instance
          .registerNsp(result.filename, result.nspBytes);

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.switchGreen, size: 28),
                SizedBox(width: 10),
                Text('NSP Generated!',
                    style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (savedPath != null) ...[
                  Text('Saved to: $savedPath',
                      style: const TextStyle(
                          color: AppTheme.switchGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                Text('Filename: ${result.filename}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                Text('Title ID: ${result.titleId}',
                    style: const TextStyle(
                        color: AppTheme.switchCyan,
                        fontFamily: 'Monospace',
                        fontSize: 13)),
                const SizedBox(height: 6),
                Text('Size: ${(result.totalSize / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12)),
              ],
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
                    style: TextStyle(color: AppTheme.switchCyan)),
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
        GamepadBrowseIntent: GamepadBrowseAction(onBrowse: _extractNroMetadata),
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
                  title: 'NRO Forwarder Generator',
                  subtitle:
                      'Create home-screen shortcuts for standalone Nintendo Switch .nro apps',
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.switchCyan,
                            side: const BorderSide(color: AppTheme.switchCyan),
                          ),
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text('Extract .NRO'),
                          onPressed: _extractNroMetadata,
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
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: _runSmartAutodetect,
                        ),
                      ),
                    ],
                  ),
                ),

                // Basic Options Card
                SwitchCard(
                  title: 'Application Details',
                  child: Column(
                    children: [
                      SwitchTextField(
                        label: 'Target NRO Path on SD Card',
                        hint: '/switch/hbmenu.nro',
                        controller: _nroPathController,
                        isPath: true,
                        prefixIcon: Icons.folder,
                        tooltip:
                            'Exact path where the .nro executable resides on your SD card.',
                        onChanged: (v) => setState(() {}),
                      ),
                      SwitchTextField(
                        label: 'Application Title',
                        hint: 'Homebrew Launcher',
                        controller: _titleController,
                        prefixIcon: Icons.title,
                        onChanged: (v) => setState(() {}),
                      ),
                      SwitchTextField(
                        label: 'Publisher / Author',
                        hint: 'Switch Dev',
                        controller: _publisherController,
                        prefixIcon: Icons.person,
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

                // Advanced Settings Accordion
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
                                  'Prompts for Nintendo Switch user profile upon app launch',
                              value: _startupUserAccount,
                              onChanged: (v) =>
                                  setState(() => _startupUserAccount = v),
                            ),
                            SwitchToggle(
                              title: 'Enable Screenshots',
                              subtitle:
                                  'Allows taking screenshots via Joy-Con capture button',
                              value: _screenshot,
                              onChanged: (v) => setState(() => _screenshot = v),
                            ),
                            SwitchToggle(
                              title: 'Enable Video Capture',
                              subtitle:
                                  'Allows holding capture button for 30s video recordings',
                              value: _videoCapture,
                              onChanged: (v) =>
                                  setState(() => _videoCapture = v),
                            ),
                            SwitchToggle(
                              title: 'Enable SVC Debug',
                              subtitle:
                                  'Enables System Call Debugging permissions for homebrew',
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
                          'Tap arrow to view startup account, capture, debug, & logo options',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                ),

                const SizedBox(height: 12),
                SwitchButton(
                  text: 'GENERATE NSP FORWARDER',
                  icon: Icons.build_circle_outlined,
                  isLoading: _isGenerating,
                  onPressed: _canGenerateNsp ? _generateNsp : null,
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
