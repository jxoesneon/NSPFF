import 'package:flutter/material.dart';
import '../theme/switch_theme.dart';

class SwitchCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  const SwitchCard({
    Key? key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.padding,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: SwitchTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? SwitchTheme.cardBorder,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: const TextStyle(
                            color: SwitchTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: SwitchTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            const Divider(color: SwitchTheme.cardBorder, height: 1),
          ],
          Padding(
            padding: padding ?? const EdgeInsets.all(18.0),
            child: child,
          ),
        ],
      ),
    );
  }
}
