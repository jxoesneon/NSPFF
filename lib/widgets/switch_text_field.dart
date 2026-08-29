import 'package:flutter/material.dart';
import '../theme/switch_theme.dart';

class SwitchTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final bool isPath;
  final String? helperText;
  final String? errorText;

  const SwitchTextField({
    Key? key,
    required this.label,
    this.hint,
    required this.controller,
    this.onChanged,
    this.prefixIcon,
    this.isPath = false,
    this.helperText,
    this.errorText,
  }) : super(key: key);

  static final RegExp _driveLetterRegex = RegExp(r'^[a-zA-Z]:');
  static final RegExp _traversalRegex = RegExp(r'\.\.[/\\]?');
  static final RegExp _multiSlashRegex = RegExp(r'/+');

  static String normalizePath(String input) {
    if (input.trim().isEmpty) return input;
    String v = input.trim().replaceAll(_driveLetterRegex, '').replaceAll('\\', '/');
    v = v.replaceAll(_traversalRegex, '').replaceAll(_multiSlashRegex, '/');
    if (!v.startsWith('/')) {
      v = '/$v';
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: (val) {
            if (isPath) {
              final normalized = normalizePath(val);
              if (normalized != val) {
                controller.value = controller.value.copyWith(
                  text: normalized,
                  selection: TextSelection.collapsed(offset: normalized.length),
                );
                if (onChanged != null) onChanged!(normalized);
                return;
              }
            }
            if (onChanged != null) onChanged!(val);
          },
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helperText,
            helperStyle: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppTheme.switchCyan, size: 20)
                : null,
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                    onPressed: () {
                      controller.clear();
                      if (onChanged != null) onChanged!('');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
