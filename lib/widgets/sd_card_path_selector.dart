// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../theme/switch_theme.dart';

class SdCardPathSelector extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<String> presetPaths;
  final ValueChanged<String>? onChanged;

  const SdCardPathSelector({
    Key? key,
    required this.label,
    required this.controller,
    required this.presetPaths,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: SwitchTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presetPaths.map((path) {
              final bool isSelected = controller.text == path;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ActionChip(
                  backgroundColor: isSelected ? SwitchTheme.switchCyan.withOpacity(0.25) : SwitchTheme.inputBackground,
                  side: BorderSide(
                    color: isSelected ? SwitchTheme.switchCyan : SwitchTheme.cardBorder,
                  ),
                  label: Text(
                    path,
                    style: SwitchTheme.monoStyle(
                      color: isSelected ? SwitchTheme.switchCyan : SwitchTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  onPressed: () {
                    controller.text = path;
                    if (onChanged != null) onChanged!(path);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
