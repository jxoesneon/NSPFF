// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/network_install_service.dart';
import '../theme/switch_theme.dart';
import 'switch_button.dart';
import 'switch_card.dart';
import 'switch_pill_badge.dart';

/// Modal dialog for 1-tap wireless console installation over local Wi-Fi.
/// Streams generated NSPs directly to Nintendo Switch DBI / Tinfoil title managers.
class NetworkInstallDialog extends StatefulWidget {
  final String? initialFilename;

  const NetworkInstallDialog({
    super.key,
    this.initialFilename,
  });

  /// Displays the NetworkInstallDialog.
  static Future<void> show(
    BuildContext context, {
    String? targetFilename,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => NetworkInstallDialog(
        initialFilename: targetFilename,
      ),
    );
  }

  @override
  State<NetworkInstallDialog> createState() => _NetworkInstallDialogState();
}

class _NetworkInstallDialogState extends State<NetworkInstallDialog> {
  final NetworkInstallService _service = NetworkInstallService.instance;
  late String? _selectedFilename;
  bool _isCopied = false;
  bool _isToggling = false;
  Timer? _copyTimer;
  final Set<int> _expandedAccordions = {0}; // 0 = DBI default expanded

  void _toggleAccordion(int index) {
    setState(() {
      if (_expandedAccordions.contains(index)) {
        _expandedAccordions.remove(index);
      } else {
        _expandedAccordions.add(index);
      }
    });
  }

  String _getServerHost() {
    final uri = Uri.tryParse(_service.serverUrl ?? '');
    return uri?.host ?? '192.168.1.X';
  }

  String _getServerPort() {
    final uri = Uri.tryParse(_service.serverUrl ?? '');
    return uri?.port.toString() ?? '8080';
  }

  @override
  void initState() {
    super.initState();
    _selectedFilename = widget.initialFilename;
    _service.addListener(_onServiceUpdate);

    // Auto-start server if not running
    if (!_service.isRunning) {
      _startServer();
    }
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _startServer() async {
    setState(() => _isToggling = true);
    try {
      await _service.startServer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start server: $e'),
            backgroundColor: AppTheme.switchRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> _stopServer() async {
    setState(() => _isToggling = true);
    await _service.stopServer();
    if (mounted) setState(() => _isToggling = false);
  }

  String _getActiveUrl() {
    if (_selectedFilename != null &&
        _service.registeredNsps.containsKey(_selectedFilename)) {
      return _service.getDirectInstallUrl(_selectedFilename!) ??
          '${_service.serverUrl ?? 'http://127.0.0.1:8080'}/';
    }
    return '${_service.serverUrl ?? 'http://127.0.0.1:8080'}/';
  }

  void _copyToClipboard(String url) {
    Clipboard.setData(ClipboardData(text: url));
    setState(() => _isCopied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Copied URL to clipboard: $url',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.switchCyan,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
    if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bytesPerSec.toStringAsFixed(0)} B/s';
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _service.isRunning;
    final activeUrl = _getActiveUrl();
    final registered = _service.registeredNsps;

    return Dialog(
      backgroundColor: AppTheme.darkBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.cardBorder, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Switch Accents
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.switchRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.switchCyan,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'WIRELESS CONSOLE INSTALLER',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Server Status Card
              SwitchCard(
                title: 'Embedded Stream Server',
                subtitle: isOnline
                    ? 'Broadcasting on local Wi-Fi network'
                    : 'Server is currently offline',
                child: Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SwitchPillBadge(
                          label: isOnline
                              ? 'ONLINE: PORT ${_service.port}'
                              : 'OFFLINE',
                          color: isOnline
                              ? AppTheme.switchGreen
                              : AppTheme.switchRed,
                          icon: isOnline ? Icons.wifi : Icons.wifi_off,
                        ),
                        if (_isToggling)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.switchCyan,
                            ),
                          )
                        else
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: isOnline
                                  ? AppTheme.switchRed
                                  : AppTheme.switchCyan,
                            ),
                            icon: Icon(isOnline
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline),
                            label:
                                Text(isOnline ? 'STOP SERVER' : 'START SERVER'),
                            onPressed: isOnline ? _stopServer : _startServer,
                          ),
                      ],
                    ),
                    if (isOnline && _service.localIp != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.router,
                              size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Host: ${_service.localIp}',
                            style: AppTheme.monoStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Title Selection (if multiple registered)
              if (registered.isNotEmpty) ...[
                if (registered.length > 1) ...[
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: registered.containsKey(_selectedFilename)
                        ? _selectedFilename
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Selected Forwarder',
                      prefixIcon: Icon(Icons.sports_esports,
                          color: AppTheme.switchCyan),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    dropdownColor: AppTheme.cardBackground,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Titles (Root Directory Index)'),
                      ),
                      ...registered.keys.map((name) {
                        return DropdownMenuItem<String?>(
                          value: name,
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedFilename = val),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // QR Code Section
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isOnline ? AppTheme.switchCyan : Colors.grey)
                            .withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: isOnline
                      ? Semantics(
                          label: 'QR code to download NSP from $activeUrl',
                          image: true,
                          child: QrImageView(
                            data: activeUrl,
                            version: QrVersions.auto,
                            size: 190.0,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          ),
                        )
                      : const SizedBox(
                          width: 190,
                          height: 190,
                          child: ColoredBox(
                            color: Colors.white,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wifi_off,
                                    size: 48, color: Colors.black45),
                                SizedBox(height: 8),
                                Text(
                                  'Server Offline',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Scan with another phone, tablet, or PC browser to download',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),

              // Direct URL & Copy Button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link,
                        size: 18, color: AppTheme.switchCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeUrl,
                        style: AppTheme.monoStyle(
                          color: isOnline
                              ? AppTheme.switchCyan
                              : AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SwitchButton(
                      text: _isCopied ? 'COPIED' : 'COPY URL',
                      icon: _isCopied ? Icons.check : Icons.copy,
                      fullWidth: false,
                      variant: _isCopied
                          ? SwitchButtonVariant.success
                          : SwitchButtonVariant.outline,
                      onPressed:
                          isOnline ? () => _copyToClipboard(activeUrl) : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Live Progress Indicator
              if (_service.isTransferring) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.switchCyan, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.downloading,
                                  color: AppTheme.switchCyan, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'STREAMING TO SWITCH...',
                                style: TextStyle(
                                  color: AppTheme.switchCyan,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _formatSpeed(_service.activeSpeedBytesPerSec),
                            style: AppTheme.monoStyle(
                              color: AppTheme.switchGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _service.activeProgressFraction,
                          backgroundColor: AppTheme.inputBackground,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.switchCyan),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _service.activeFilename ?? 'Streaming NSP',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_formatBytes(_service.activeBytesSent)} / ${_formatBytes(_service.activeTotalBytes)} (${(_service.activeProgressFraction * 100).toStringAsFixed(0)}%)',
                            style: AppTheme.monoStyle(
                                color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // HOW TO INSTALL section with multi-installer accordions
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.help_outline_rounded,
                            color: AppTheme.switchCyan, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'HOW TO INSTALL',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.switchCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CHOOSE INSTALLER',
                            style: TextStyle(
                              color: AppTheme.switchCyan,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select your Switch title manager for step-by-step instructions. Both devices must be connected to the same Wi-Fi network.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Accordion 1: DBI (Recommended)
                    _InstallOptionAccordion(
                      title: 'DBI Installer',
                      subtitle: 'Network stream install (fastest & easiest)',
                      icon: Icons.bolt,
                      iconColor: AppTheme.switchCyan,
                      badgeText: 'RECOMMENDED',
                      badgeColor: AppTheme.switchCyan,
                      isExpanded: _expandedAccordions.contains(0),
                      onTap: () => _toggleAccordion(0),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepRow(
                              '1', 'Open DBI on your Nintendo Switch.'),
                          _buildStepRow('2',
                              'Select "Install title from DBI backend / URL".'),
                          _buildStepRow('3',
                              'Enter the stream URL below and press A to install:'),
                          const SizedBox(height: 6),
                          _buildUrlSnippet(activeUrl),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.inputBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.lightbulb_outline,
                                        color: AppTheme.switchCyan, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'Optional: Save in dbi.config',
                                      style: TextStyle(
                                        color: AppTheme.switchCyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add under [Network install sources] in sdmc:/switch/dbi/dbi.config:\nNSPFF = $activeUrl',
                                  style: AppTheme.monoStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Accordion 2: Tinfoil
                    _InstallOptionAccordion(
                      title: 'Tinfoil',
                      subtitle: 'File Browser HTTP index source',
                      icon: Icons.folder_special,
                      iconColor: AppTheme.switchRed,
                      badgeText: 'POPULAR',
                      badgeColor: AppTheme.switchRed,
                      isExpanded: _expandedAccordions.contains(1),
                      onTap: () => _toggleAccordion(1),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepRow('1',
                              'Open Tinfoil on your Switch and select "File Browser".'),
                          _buildStepRow('2',
                              'Press - (Minus) to add a new location with these settings:'),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.inputBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildConfigItem('Protocol', 'http'),
                                _buildConfigItem('Host', _getServerHost()),
                                _buildConfigItem('Port', _getServerPort()),
                                _buildConfigItem('Path', '/'),
                                _buildConfigItem('Title', 'NSPFF Stream'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildStepRow('3',
                              'Press Save, open the new source, and choose the .nsp file to install.'),
                        ],
                      ),
                    ),

                    // Accordion 3: Awoo / TinWoo
                    _InstallOptionAccordion(
                      title: 'Awoo / TinWoo',
                      subtitle: 'Direct LAN & Internet URL install',
                      icon: Icons.pets,
                      iconColor: const Color(0xFFFF9500),
                      isExpanded: _expandedAccordions.contains(2),
                      onTap: () => _toggleAccordion(2),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepRow('1',
                              'Open Awoo Installer or TinWoo on your Switch.'),
                          _buildStepRow('2',
                              'Select "Install over LAN or internet" -> "Install from URL".'),
                          _buildStepRow(
                              '3', 'Enter the direct .nsp stream URL:'),
                          const SizedBox(height: 6),
                          _buildUrlSnippet(activeUrl),
                          const SizedBox(height: 8),
                          _buildStepRow(
                              '4', 'Press + (Plus) to begin the installation.'),
                        ],
                      ),
                    ),

                    // Accordion 4: Web Browser & PC
                    _InstallOptionAccordion(
                      title: 'Web Browser & PC',
                      subtitle: 'Download via PC, Mac, or tablet browser',
                      icon: Icons.language,
                      iconColor: const Color(0xFF38BDF8),
                      isExpanded: _expandedAccordions.contains(3),
                      onTap: () => _toggleAccordion(3),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepRow('1',
                              'Connect any PC, Mac, or tablet to the same local Wi-Fi.'),
                          _buildStepRow('2',
                              'Scan the QR code at top, or open this URL in any browser:'),
                          const SizedBox(height: 6),
                          _buildUrlSnippet(_service.serverUrl != null
                              ? '${_service.serverUrl}/'
                              : 'http://127.0.0.1:8080/'),
                          const SizedBox(height: 8),
                          _buildStepRow('3',
                              'Browse the files and download any generated .nsp directly.'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Wi-Fi Troubleshooting Tip Box
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.inputBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.cardBorder,
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.wifi_find,
                              color: AppTheme.switchCyan, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Network Note: Both devices must be on the same local Wi-Fi network. If connection fails, ensure "AP Isolation" is disabled on your router, or connect your Switch to your phone\'s Wi-Fi Hotspot.',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 10.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Done Button
              SwitchButton(
                text: 'DONE',
                icon: Icons.check,
                variant: SwitchButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.cardBorder,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlSnippet(String url) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              url,
              style: AppTheme.monoStyle(
                color: AppTheme.switchCyan,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Copy direct install URL',
            child: IconButton(
              icon: const Icon(
                Icons.copy,
                size: 14,
                color: AppTheme.switchCyan,
              ),
              tooltip: 'Copy direct install URL',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () => _copyToClipboard(url),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$key:',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: AppTheme.monoStyle(
              color: AppTheme.switchCyan,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// An interactive accordion for installer-specific steps.
class _InstallOptionAccordion extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final String? badgeText;
  final Color? badgeColor;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget content;

  const _InstallOptionAccordion({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    this.badgeText,
    this.badgeColor,
    required this.isExpanded,
    required this.onTap,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? AppTheme.switchCyan.withValues(alpha: 0.7)
              : AppTheme.cardBorder,
          width: isExpanded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (badgeText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (badgeColor ?? AppTheme.switchCyan)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: (badgeColor ?? AppTheme.switchCyan)
                                        .withValues(alpha: 0.6),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  badgeText!,
                                  style: TextStyle(
                                    color: badgeColor ?? AppTheme.switchCyan,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  const SizedBox(height: 12),
                  content,
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
