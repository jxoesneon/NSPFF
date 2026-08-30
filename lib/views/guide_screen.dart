import 'package:flutter/material.dart';
import '../theme/switch_theme.dart';
import '../widgets/switch_card.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchCard(
            title: 'How to Dump prod.keys',
            subtitle:
                'Keys from a Nintendo Switch console are required to sign forwarders',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuideStep(
                  stepNumber: '1',
                  title: 'Get Lockpick_RCM',
                  description:
                      'Download the latest Lockpick_RCM.bin payload from a trusted homebrew source.',
                ),
                _GuideStep(
                  stepNumber: '2',
                  title: 'Enter RCM Mode',
                  description:
                      'Place the Switch into RCM mode and inject the Lockpick_RCM payload using a PC or web injector.',
                ),
                _GuideStep(
                  stepNumber: '3',
                  title: 'Dump from SysNAND',
                  description:
                      'In the payload menu, select "Dump from SysNAND". This scans the console for the required cryptographic keys.',
                ),
                _GuideStep(
                  stepNumber: '4',
                  title: 'Locate prod.keys',
                  description:
                      'Keys are saved to "/switch/prod.keys" on the SD card. Copy this file to the Android device.',
                ),
              ],
            ),
          ),
          SwitchCard(
            title: 'Installation & Ban Safety Guide',
            subtitle:
                'Best practices for installing NSP forwarders safely on Nintendo Switch',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuideStep(
                  stepNumber: '1',
                  title: 'Required Sigpatches',
                  description:
                      'Ensure the modded Switch has up-to-date Atmosphere sigpatches (ES/FS patches) installed, otherwise custom NSPs fail to launch with Error 2016-1263.',
                ),
                _GuideStep(
                  stepNumber: '2',
                  title: 'NRO & Core Paths Must Match Exactly',
                  description:
                      'Forwarders act as shortcuts pointing to hardcoded SD card paths. Do not move or rename the target .nro or ROM files after generating the NSP.',
                ),
                _GuideStep(
                  stepNumber: '3',
                  title: 'Installation via DBI / Awoo',
                  description:
                      'Copy the generated .nsp file to the SD card or install directly over USB/MTP using DBI Installer, Awoo, or Goldleaf.',
                ),
                _GuideStep(
                  stepNumber: '4',
                  title: 'Console Ban Prevention',
                  description:
                      'Installing custom forwarder NSPs modifies system ticket databases. Always use DNS MITM or Exosphere on an offline emuMMC to prevent console bans from Nintendo servers.',
                ),
              ],
            ),
          ),
          SwitchCard(
            title: 'Parity & Feature Comparison',
            child: Column(
              children: [
                _ParityRow(
                    feature: 'NRO Forwarder Generation',
                    web: 'Yes',
                    app: 'Yes 1:1'),
                _ParityRow(
                    feature: 'RetroArch Core & ROM Forwarding',
                    web: 'Yes',
                    app: 'Yes 1:1'),
                _ParityRow(
                    feature: 'Advanced Startup & Capture Flags',
                    web: 'Yes',
                    app: 'Yes 1:1'),
                _ParityRow(
                    feature: 'Auto NACP Metadata Extraction',
                    web: 'Yes',
                    app: 'Yes 1:1'),
                _ParityRow(
                    feature: 'Custom Boxart & Icon 256x256 Crop',
                    web: 'Yes',
                    app: 'Yes 1:1+'),
                _ParityRow(
                    feature: 'Batch Multi-ROM Forwarders',
                    web: 'No',
                    app: 'Exceeds (+ Batch)'),
                _ParityRow(
                    feature: 'Saved Preset History & Key Manager',
                    web: 'No',
                    app: 'Exceeds (+ Saved)'),
                _ParityRow(
                    feature: 'Offline Android Client Generation',
                    web: 'No',
                    app: 'Exceeds (+ Native)'),
              ],
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String description;

  const _GuideStep({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.switchCyan,
            child: Text(
              stepNumber,
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParityRow extends StatelessWidget {
  final String feature;
  final String web;
  final String app;

  const _ParityRow({
    required this.feature,
    required this.web,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(feature,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text(web,
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              app,
              style: TextStyle(
                color: app.contains('Exceeds')
                    ? AppTheme.switchGreen
                    : AppTheme.switchCyan,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
