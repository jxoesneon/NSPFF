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
    super.key,
    required this.label,
    required this.controller,
    required this.presetPaths,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
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
                  backgroundColor: isSelected
                      ? AppTheme.switchCyan.withValues(alpha: 0.25)
                      : AppTheme.inputBackground,
                  side: BorderSide(
                    color:
                        isSelected ? AppTheme.switchCyan : AppTheme.cardBorder,
                  ),
                  label: Text(
                    path,
                    style: AppTheme.monoStyle(
                      color: isSelected
                          ? AppTheme.switchCyan
                          : AppTheme.textSecondary,
                      fontSize: 12,
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
