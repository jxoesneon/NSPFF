import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/switch_theme.dart';

class TitleIdInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const TitleIdInput({
    Key? key,
    required this.controller,
    this.onChanged,
  }) : super(key: key);

  static String generateRandomID() {
    final rand = Random();
    final buffer = StringBuffer('05');
    for (int i = 0; i < 14; i++) {
      buffer.write(rand.nextInt(16).toRadixString(16).toUpperCase());
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bool isValidHex = RegExp(r'^[0-9A-Fa-f]{16}$').hasMatch(controller.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Title ID (16-Hex)',
              style: TextStyle(
                color: SwitchTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                final newId = generateRandomID();
                controller.text = newId;
                if (onChanged != null) onChanged!(newId);
              },
              child: const Row(
                children: [
                  Icon(Icons.autorenew, size: 14, color: SwitchTheme.switchCyan),
                  SizedBox(width: 4),
                  Text(
                    'Randomize',
                    style: TextStyle(
                      color: SwitchTheme.switchCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: (val) {
            final upper = val.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
            if (upper != val) {
              controller.value = controller.value.copyWith(
                text: upper,
                selection: TextSelection.collapsed(offset: upper.length),
              );
            }
            if (onChanged != null) onChanged!(upper);
          },
          maxLength: 16,
          style: TextStyle(
            color: isValidHex ? SwitchTheme.textPrimary : SwitchTheme.switchRed,
            fontFamily: 'Monospace',
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '0500000000000001',
            prefixIcon: const Icon(Icons.fingerprint, color: SwitchTheme.switchCyan),
            suffixIcon: Icon(
              isValidHex ? Icons.check_circle : Icons.warning_amber_rounded,
              color: isValidHex ? SwitchTheme.switchGreen : SwitchTheme.switchRed,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
