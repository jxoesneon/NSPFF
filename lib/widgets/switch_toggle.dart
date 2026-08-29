import 'package:flutter/material.dart';
import '../theme/switch_theme.dart';

class SwitchToggle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchToggle({
    Key? key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: SwitchTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: SwitchTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: SwitchTheme.switchCyan,
            activeTrackColor: SwitchTheme.switchCyan.withOpacity(0.3),
            inactiveThumbColor: SwitchTheme.textMuted,
            inactiveTrackColor: SwitchTheme.inputBackground,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
