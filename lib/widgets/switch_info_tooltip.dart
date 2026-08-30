import 'package:flutter/material.dart';
import '../theme/switch_theme.dart';

/// A reusable Nintendo Switch Horizon OS styled info icon with a long-press
/// tooltip that remains visible while the user holds focus / hover.
class SwitchInfoTooltip extends StatelessWidget {
  final String message;

  const SwitchInfoTooltip({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 5),
      waitDuration: Duration.zero,
      preferBelow: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.switchCyan.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 12,
        height: 1.35,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppTheme.switchCyan,
          ),
        ),
      ),
    );
  }
}
