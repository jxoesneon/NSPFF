import 'package:flutter/material.dart';
import '../theme/switch_gamepad_navigation.dart';
import '../theme/switch_theme.dart';

class SwitchCard extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool isFocusable;

  const SwitchCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.padding,
    this.borderColor,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.isFocusable = false,
  });

  @override
  State<SwitchCard> createState() => _SwitchCardState();
}

class _SwitchCardState extends State<SwitchCard> {
  FocusNode? _internalFocusNode;
  bool _isFocused = false;

  bool get _canFocus =>
      widget.isFocusable || widget.onTap != null || widget.focusNode != null;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    if (_canFocus) {
      _effectiveFocusNode.addListener(_handleFocusChange);
      _isFocused = _effectiveFocusNode.hasFocus;
    }
  }

  @override
  void didUpdateWidget(SwitchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)
          ?.removeListener(_handleFocusChange);
      if (_canFocus) {
        _effectiveFocusNode.addListener(_handleFocusChange);
        _isFocused = _effectiveFocusNode.hasFocus;
      }
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted && _isFocused != _effectiveFocusNode.hasFocus) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBorder = _isFocused
        ? Border.all(color: AppTheme.switchCyan, width: 2)
        : Border.all(
            color: widget.borderColor ?? AppTheme.cardBorder,
            width: 1,
          );

    final cardShadow = _isFocused
        ? [
            BoxShadow(
              color: AppTheme.switchCyan.withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ]
        : const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ];

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title!,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
            const Divider(color: AppTheme.cardBorder, height: 1),
          ],
          Padding(
            padding: widget.padding ?? const EdgeInsets.all(16.0),
            child: widget.child,
          ),
        ],
      ),
    );

    if (_canFocus) {
      content = FocusableActionDetector(
        focusNode: _effectiveFocusNode,
        autofocus: widget.autofocus,
        onFocusChange: (f) {
          if (mounted && _isFocused != f) {
            setState(() {
              _isFocused = f;
            });
          }
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return true;
            },
          ),
          GamepadConfirmIntent: CallbackAction<GamepadConfirmIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return true;
            },
          ),
        },
        child: widget.onTap != null
            ? InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: content,
              )
            : content,
      );
    }

    return content;
  }
}
