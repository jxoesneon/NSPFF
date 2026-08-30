import 'package:flutter/material.dart';
import '../theme/switch_theme.dart';
import 'switch_info_tooltip.dart';

class SwitchTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final bool isPath;
  final String? helperText;
  final String? tooltip;
  final String? errorText;
  final int maxLines;
  final Widget? suffixAction;
  final FocusNode? focusNode;
  final bool autofocus;

  const SwitchTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.onChanged,
    this.prefixIcon,
    this.isPath = false,
    this.helperText,
    this.tooltip,
    this.errorText,
    this.maxLines = 1,
    this.suffixAction,
    this.focusNode,
    this.autofocus = false,
  });

  static final RegExp _driveLetterRegex = RegExp(r'^[a-zA-Z]:');
  static final RegExp _traversalRegex = RegExp(r'\.\.[/\\]?');
  static final RegExp _multiSlashRegex = RegExp(r'/+');

  static String normalizePath(String input) {
    if (input.trim().isEmpty) return input;
    String v =
        input.trim().replaceAll(_driveLetterRegex, '').replaceAll('\\', '/');
    v = v.replaceAll(_traversalRegex, '').replaceAll(_multiSlashRegex, '/');
    if (!v.startsWith('/')) {
      v = '/$v';
    }
    return v;
  }

  @override
  State<SwitchTextField> createState() => _SwitchTextFieldState();
}

class _SwitchTextFieldState extends State<SwitchTextField> {
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
  void didUpdateWidget(SwitchTextField oldWidget) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTooltip = widget.tooltip ??
        (widget.helperText != null && widget.helperText!.length > 35
            ? widget.helperText
            : null);
    final effectiveHelperText = widget.tooltip != null
        ? null
        : (widget.helperText != null && widget.helperText!.length <= 35
            ? widget.helperText
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (effectiveTooltip != null && effectiveTooltip.isNotEmpty) ...[
              const SizedBox(width: 4),
              SwitchInfoTooltip(message: effectiveTooltip),
            ],
          ],
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? AppTheme.switchCyan : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.switchCyan.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1.5,
                    ),
                  ]
                : null,
          ),
          child: Semantics(
            label: widget.label,
            child: TextField(
              focusNode: _effectiveFocusNode,
              autofocus: widget.autofocus,
              controller: widget.controller,
              maxLines: widget.maxLines,
              onChanged: (val) {
                if (widget.isPath) {
                  final normalized = SwitchTextField.normalizePath(val);
                  if (normalized != val) {
                    widget.controller.value = widget.controller.value.copyWith(
                      text: normalized,
                      selection:
                          TextSelection.collapsed(offset: normalized.length),
                    );
                    if (widget.onChanged != null) widget.onChanged!(normalized);
                    return;
                  }
                }
                if (widget.onChanged != null) widget.onChanged!(val);
              },
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                errorText: widget.errorText,
                helperText: effectiveHelperText,
                helperStyle:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                prefixIcon: widget.prefixIcon != null
                    ? Icon(widget.prefixIcon,
                        color: AppTheme.switchCyan, size: 20)
                    : null,
                suffixIcon: widget.suffixAction ??
                    (widget.controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                size: 18, color: AppTheme.textMuted),
                            onPressed: () {
                              widget.controller.clear();
                              if (widget.onChanged != null) {
                                widget.onChanged!('');
                              }
                            },
                          )
                        : null),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
