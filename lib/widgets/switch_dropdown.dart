import 'package:flutter/material.dart';
import '../models/retroarch_core.dart';
import '../models/forwarder_config.dart';
import '../theme/switch_theme.dart';

class RetroArchCoreDropdown extends StatelessWidget {
  final RetroArchCore? selectedCore;
  final ValueChanged<RetroArchCore?> onChanged;

  const RetroArchCoreDropdown({
    Key? key,
    required this.selectedCore,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RetroArch Core Preset',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<RetroArchCore>(
              value: selectedCore,
              isExpanded: true,
              dropdownColor: AppTheme.cardBackground,
              hint: Text(
                'Select RetroArch Core...',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              items: RetroArchCore.builtInCores.map((core) {
                return DropdownMenuItem<RetroArchCore>(
                  value: core,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.switchCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          core.category,
                          style: TextStyle(
                            color: AppTheme.switchCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          core.displayName,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class LogoTypeDropdown extends StatelessWidget {
  final LogoType selectedLogo;
  final ValueChanged<LogoType> onChanged;

  const LogoTypeDropdown({
    Key? key,
    required this.selectedLogo,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Startup Logo Type',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<LogoType>(
              value: selectedLogo,
              isExpanded: true,
              dropdownColor: AppTheme.cardBackground,
              items: LogoType.values.map((logo) {
                return DropdownMenuItem<LogoType>(
                  value: logo,
                  child: Text(
                    logo.label,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
