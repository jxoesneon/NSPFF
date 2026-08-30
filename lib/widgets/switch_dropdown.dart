import 'package:flutter/material.dart';
import '../models/retroarch_core.dart';
import '../models/forwarder_config.dart';
import '../theme/switch_theme.dart';

class RetroArchCoreDropdown extends StatefulWidget {
  final RetroArchCore? selectedCore;
  final ValueChanged<RetroArchCore?> onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  const RetroArchCoreDropdown({
    super.key,
    required this.selectedCore,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<RetroArchCoreDropdown> createState() => _RetroArchCoreDropdownState();
}

class _RetroArchCoreDropdownState extends State<RetroArchCoreDropdown> {
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
  void didUpdateWidget(RetroArchCoreDropdown oldWidget) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RetroArch Core Preset',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? AppTheme.switchCyan : AppTheme.cardBorder,
              width: _isFocused ? 2 : 1,
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
            label: 'RetroArch Core Preset',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<RetroArchCore>(
                focusNode: _effectiveFocusNode,
                autofocus: widget.autofocus,
                value: widget.selectedCore,
                isExpanded: true,
                dropdownColor: AppTheme.cardBackground,
                hint: const Text(
                  'Select RetroArch Core...',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
                items: RetroArchCore.builtInCores.map((core) {
                  return DropdownMenuItem<RetroArchCore>(
                    value: core,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.switchCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            core.category,
                            style: const TextStyle(
                              color: AppTheme.switchCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            core.displayName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class LogoTypeDropdown extends StatefulWidget {
  final LogoType selectedLogo;
  final ValueChanged<LogoType> onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  const LogoTypeDropdown({
    super.key,
    required this.selectedLogo,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<LogoTypeDropdown> createState() => _LogoTypeDropdownState();
}

class _LogoTypeDropdownState extends State<LogoTypeDropdown> {
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
  void didUpdateWidget(LogoTypeDropdown oldWidget) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Startup Logo Type',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? AppTheme.switchCyan : AppTheme.cardBorder,
              width: _isFocused ? 2 : 1,
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
            label: 'Startup Logo Type',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LogoType>(
                focusNode: _effectiveFocusNode,
                autofocus: widget.autofocus,
                value: widget.selectedLogo,
                isExpanded: true,
                dropdownColor: AppTheme.cardBackground,
                items: LogoType.values.map((logo) {
                  return DropdownMenuItem<LogoType>(
                    value: logo,
                    child: Text(
                      logo.label,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) widget.onChanged(val);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
