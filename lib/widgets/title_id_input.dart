// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/title_id.dart';
import '../services/title_id_registry_service.dart';
import '../theme/switch_gamepad_navigation.dart';
import '../theme/switch_theme.dart';
import 'switch_info_tooltip.dart';

class TitleIdInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String label;
  final String? tooltip;
  final bool showBatchPreview;
  final FocusNode? focusNode;
  final bool autofocus;
  final FocusNode? randomizeFocusNode;

  const TitleIdInput({
    super.key,
    required this.controller,
    this.onChanged,
    this.label = 'Title ID (16-Hex)',
    this.tooltip =
        '16-character hexadecimal unique identifier. Homebrew forwarders use 05XXXXXXXXXXXXXX to avoid collisions with official Nintendo titles.',
    this.showBatchPreview = false,
    this.focusNode,
    this.autofocus = false,
    this.randomizeFocusNode,
  });

  /// Generates a cryptographically random 16-hex Title ID in the homebrew
  /// 0x05 range, validating it against [TitleIdRegistryService] for
  /// collisions before returning.
  static String generateRandomID() => TitleId.generateRandomId();

  @override
  State<TitleIdInput> createState() => _TitleIdInputState();
}

class _TitleIdInputState extends State<TitleIdInput> {
  static final RegExp _nonHexRegex = RegExp(r'[^0-9A-F]');

  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());
  bool _isFieldFocused = false;

  FocusNode? _internalRandomizeFocusNode;
  FocusNode get _effectiveRandomizeFocusNode =>
      widget.randomizeFocusNode ??
      (_internalRandomizeFocusNode ??= FocusNode());
  bool _isRandomizeFocused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);

    _effectiveFocusNode.addListener(_handleFieldFocusChange);
    _isFieldFocused = _effectiveFocusNode.hasFocus;

    _effectiveRandomizeFocusNode.addListener(_handleRandomizeFocusChange);
    _isRandomizeFocused = _effectiveRandomizeFocusNode.hasFocus;

    // Warm up the TitleIdRegistryService registered IDs cache
    TitleIdRegistryService.getRegisteredTitleIds().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(TitleIdInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)
          ?.removeListener(_handleFieldFocusChange);
      _effectiveFocusNode.addListener(_handleFieldFocusChange);
      _isFieldFocused = _effectiveFocusNode.hasFocus;
    }
    if (oldWidget.randomizeFocusNode != widget.randomizeFocusNode) {
      (oldWidget.randomizeFocusNode ?? _internalRandomizeFocusNode)
          ?.removeListener(_handleRandomizeFocusChange);
      _effectiveRandomizeFocusNode.addListener(_handleRandomizeFocusChange);
      _isRandomizeFocused = _effectiveRandomizeFocusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _effectiveFocusNode.removeListener(_handleFieldFocusChange);
    _internalFocusNode?.dispose();
    _effectiveRandomizeFocusNode.removeListener(_handleRandomizeFocusChange);
    _internalRandomizeFocusNode?.dispose();
    super.dispose();
  }

  void _handleFieldFocusChange() {
    if (mounted && _isFieldFocused != _effectiveFocusNode.hasFocus) {
      setState(() {
        _isFieldFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  void _handleRandomizeFocusChange() {
    if (mounted &&
        _isRandomizeFocused != _effectiveRandomizeFocusNode.hasFocus) {
      setState(() {
        _isRandomizeFocused = _effectiveRandomizeFocusNode.hasFocus;
      });
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _randomize() {
    unawaited(
      TitleIdRegistryService.getRegisteredTitleIds().then((_) {
        if (!mounted) return;
        final newId = TitleIdInput.generateRandomID();
        widget.controller.text = newId;
        if (widget.onChanged != null) widget.onChanged!(newId);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text.trim();
    final validation = TitleIdRegistryService.validateTitleId(text);

    final Color statusColor;
    final IconData statusIcon;
    if (text.isEmpty) {
      statusColor = AppTheme.textSecondary;
      statusIcon = Icons.fingerprint;
    } else if (validation.isReservedSystem || validation.isRegistered) {
      statusColor = AppTheme.switchRed;
      statusIcon = validation.isReservedSystem
          ? Icons.gpp_bad_rounded
          : Icons.block_rounded;
    } else if (validation.isRetailConflict) {
      statusColor = AppTheme.switchYellow;
      statusIcon = Icons.storefront_rounded;
    } else if (!validation.isValid) {
      statusColor = AppTheme.switchRed;
      statusIcon = Icons.warning_amber_rounded;
    } else if (!validation.isInHomebrewRange) {
      statusColor = AppTheme.switchYellow;
      statusIcon = Icons.info_outline_rounded;
    } else {
      statusColor = AppTheme.switchGreen;
      statusIcon = Icons.check_circle_rounded;
    }

    return Actions(
      actions: {
        GamepadQuickActionIntent: GamepadQuickAction(onQuickAction: _randomize),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  if (widget.tooltip != null && widget.tooltip!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    SwitchInfoTooltip(message: widget.tooltip!),
                  ],
                ],
              ),
              Semantics(
                button: true,
                label: 'Randomize Title ID',
                child: FocusableActionDetector(
                  focusNode: _effectiveRandomizeFocusNode,
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        _randomize();
                        return true;
                      },
                    ),
                    GamepadConfirmIntent: CallbackAction<GamepadConfirmIntent>(
                      onInvoke: (_) {
                        _randomize();
                        return true;
                      },
                    ),
                  },
                  child: InkWell(
                    onTap: _randomize,
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      constraints:
                          const BoxConstraints(minHeight: 44, minWidth: 44),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isRandomizeFocused
                              ? AppTheme.switchCyan
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: _isRandomizeFocused
                            ? [
                                BoxShadow(
                                  color: AppTheme.switchCyan
                                      .withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.autorenew,
                              size: 16, color: AppTheme.switchCyan),
                          SizedBox(width: 6),
                          Text(
                            'Randomize',
                            style: TextStyle(
                              color: AppTheme.switchCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _isFieldFocused ? AppTheme.switchCyan : Colors.transparent,
                width: 2,
              ),
              boxShadow: _isFieldFocused
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
                onChanged: (val) {
                  final upper = val.toUpperCase().replaceAll(_nonHexRegex, '');
                  if (upper != val) {
                    widget.controller.value = widget.controller.value.copyWith(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                  if (widget.onChanged != null) widget.onChanged!(upper);
                },
                maxLength: 16,
                style: AppTheme.monoStyle(
                  color: (validation.isValid && !validation.isRegistered)
                      ? (validation.isRetailConflict ||
                              !validation.isInHomebrewRange
                          ? AppTheme.switchYellow
                          : AppTheme.textPrimary)
                      : (text.isEmpty
                          ? AppTheme.textPrimary
                          : AppTheme.switchRed),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '0500000000000001',
                  prefixIcon:
                      const Icon(Icons.fingerprint, color: AppTheme.switchCyan),
                  suffixIcon: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          _buildValidationBadge(validation, text),
          if (widget.showBatchPreview && validation.isValid) ...[
            const SizedBox(height: 12),
            _BatchPreview(baseId: widget.controller.text),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildValidationBadge(TitleIdValidationResult result, String text) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    if (result.isReservedSystem) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.switchRed,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.switchRed),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.gpp_bad_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.switchRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CRITICAL SYSTEM CONFLICT',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.warningMessage ??
                        'Reserved Nintendo System Title! Overwriting will corrupt Switch OS.',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (result.isRegistered) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.switchRed,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.switchRed),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.switchRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CONFLICT: ALREADY REGISTERED',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.warningMessage ??
                        'This Title ID is already in use by another forwarder on this device.',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (result.isRetailConflict) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.switchYellow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.switchYellow),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.storefront_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.switchYellow.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.switchYellow),
                    ),
                    child: const Text(
                      'RETAIL GAME CONFLICT',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.warningMessage ??
                        '0100... Title IDs are reserved for official retail games. Use 05... for homebrew forwarders.',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (result.warningMessage != null) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.switchYellow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.switchYellow),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.warningMessage!,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (result.isValid && result.isInHomebrewRange) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 14, color: AppTheme.switchGreen),
            SizedBox(width: 6),
            Text(
              'Valid Homebrew Forwarder ID (05...)',
              style: TextStyle(
                color: AppTheme.switchGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _BatchPreview extends StatelessWidget {
  final String baseId;

  const _BatchPreview({required this.baseId});

  @override
  Widget build(BuildContext context) {
    BigInt? id;
    try {
      id = BigInt.parse(baseId, radix: 16);
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.inputBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: 14, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Text(
                'SEQUENTIAL PREVIEW',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(
                    '${i + 1}. ',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                  ),
                  Text(
                    (id + BigInt.from(i))
                        .toRadixString(16)
                        .toUpperCase()
                        .padLeft(16, '0'),
                    style: AppTheme.monoStyle(
                        fontSize: 12,
                        color: AppTheme.switchCyan.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          const Text(
            '...',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
