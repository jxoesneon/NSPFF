import 'package:flutter/material.dart';
import '../theme/switch_theme.dart';

enum SwitchButtonVariant { primary, secondary, outline }

class SwitchButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final SwitchButtonVariant variant;
  final bool fullWidth;

  const SwitchButton({
    Key? key,
    required this.text,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.variant = SwitchButtonVariant.primary,
    this.fullWidth = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case SwitchButtonVariant.primary:
        bg = AppTheme.switchCyan;
        fg = Colors.black;
        break;
      case SwitchButtonVariant.secondary:
        bg = AppTheme.switchRed;
        fg = Colors.black; // AAA Contrast (7.05:1) on Switch Red
        break;
      case SwitchButtonVariant.outline:
        bg = Colors.transparent;
        fg = AppTheme.switchCyan;
        border = const BorderSide(color: AppTheme.switchCyan, width: 1.5);
        break;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );

    final buttonWidget = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        side: border,
        elevation: variant == SwitchButtonVariant.outline ? 0 : 3,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: isLoading ? null : onPressed,
      child: content,
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}
