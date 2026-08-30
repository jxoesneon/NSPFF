import 'package:flutter/material.dart';
import 'package:iconic_morph/iconic_morph.dart';
import '../theme/switch_theme.dart';
import '../theme/switch_icons.dart';

enum SwitchButtonVariant { primary, secondary, success, outline }

class SwitchButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final IconData? successIcon;
  final bool isSuccess;
  final VoidCallback? onPressed;
  final bool isLoading;
  final SwitchButtonVariant variant;
  final bool fullWidth;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  const SwitchButton({
    super.key,
    required this.text,
    this.icon,
    this.successIcon,
    this.isSuccess = false,
    this.onPressed,
    this.isLoading = false,
    this.variant = SwitchButtonVariant.primary,
    this.fullWidth = true,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
  });

  @override
  State<SwitchButton> createState() => _SwitchButtonState();
}

class _SwitchButtonState extends State<SwitchButton> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_handleFocusChange);
    _isFocused = _effectiveFocusNode.hasFocus;
  }

  @override
  void didUpdateWidget(SwitchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)
          ?.removeListener(_handleFocusChange);
      _effectiveFocusNode.addListener(_handleFocusChange);
      _isFocused = _effectiveFocusNode.hasFocus;
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
      widget.onFocusChange?.call(_isFocused);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    final currentVariant =
        widget.isSuccess ? SwitchButtonVariant.success : widget.variant;

    Color glowColor = AppTheme.switchCyan;

    switch (currentVariant) {
      case SwitchButtonVariant.primary:
        bg = AppTheme.switchCyan;
        fg = Colors.black;
        glowColor = AppTheme.switchCyan;
        break;
      case SwitchButtonVariant.secondary:
        bg = AppTheme.switchRed;
        fg = Colors.black;
        glowColor = AppTheme.switchRed;
        break;
      case SwitchButtonVariant.success:
        bg = AppTheme.switchGreen;
        fg = Colors.black;
        glowColor = AppTheme.switchGreen;
        break;
      case SwitchButtonVariant.outline:
        bg = Colors.transparent;
        fg = AppTheme.switchCyan;
        border = const BorderSide(color: AppTheme.switchCyan, width: 1.5);
        glowColor = AppTheme.switchCyan;
        break;
    }

    Widget? iconWidget;
    if (widget.isLoading) {
      iconWidget = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else if (widget.isSuccess) {
      if (IconGeometry.resolver != null) {
        String startIcon = SwitchIcons.plus;
        if (widget.icon == Icons.save) startIcon = SwitchIcons.plus;
        if (widget.icon == Icons.delete_forever) startIcon = SwitchIcons.keyOff;

        iconWidget = IconicMorph(
          startIcon,
          SwitchIcons.check,
          autoplay: true,
          plan: const IconMorphPlan(duration: Duration(milliseconds: 400)),
          size: 20,
          color: fg,
        );
      } else {
        iconWidget =
            Icon(widget.successIcon ?? Icons.check_circle, size: 20, color: fg);
      }
    } else if (widget.icon != null) {
      iconWidget = Icon(widget.icon, size: 20, color: fg);
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (iconWidget != null) ...[
          iconWidget,
          const SizedBox(width: 8),
        ],
        Text(
          widget.isSuccess ? 'SUCCESS!' : widget.text,
          style: TextStyle(
            color: fg,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );

    final buttonWidget = ElevatedButton(
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        if (mounted && _isFocused != focused) {
          setState(() {
            _isFocused = focused;
          });
          widget.onFocusChange?.call(focused);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        side: border,
        elevation: widget.variant == SwitchButtonVariant.outline ? 0 : 3,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed:
          (widget.isLoading || widget.isSuccess) ? null : widget.onPressed,
      child: content,
    );

    final glowingButton = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isFocused ? glowColor : Colors.transparent,
          width: 2,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: buttonWidget,
    );

    if (widget.fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: glowingButton,
      );
    }

    return glowingButton;
  }
}
