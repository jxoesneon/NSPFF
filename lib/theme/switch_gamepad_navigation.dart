// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'switch_theme.dart';

// =============================================================================
// GAMEPAD INTENTS (Nintendo Switch / Handheld Controller Layout)
// =============================================================================

/// Intent for Confirm / Activate action (A button, Select, Enter)
class GamepadConfirmIntent extends Intent {
  const GamepadConfirmIntent();
}

/// Intent for Back / Dismiss action (B button, Escape, Backspace)
class GamepadBackIntent extends Intent {
  const GamepadBackIntent();
}

/// Intent for Quick Auto-Fill / Secondary action (X button)
class GamepadQuickActionIntent extends Intent {
  const GamepadQuickActionIntent();
}

/// Intent for Browse / Pick File action (Y button)
class GamepadBrowseIntent extends Intent {
  const GamepadBrowseIntent();
}

/// Intent for Previous Tab action (L / LB / L1 button)
class GamepadPrevTabIntent extends Intent {
  const GamepadPrevTabIntent();
}

/// Intent for Next Tab action (R / RB / R1 button)
class GamepadNextTabIntent extends Intent {
  const GamepadNextTabIntent();
}

/// Intent for Run / Generate action (Start / + / ContextMenu button)
class GamepadStartIntent extends Intent {
  const GamepadStartIntent();
}

/// Intent to toggle gamepad HUD visibility (Minus / Select button)
class GamepadToggleHudIntent extends Intent {
  const GamepadToggleHudIntent();
}

// =============================================================================
// SHORTCUT ACTIVATORS MAPPING
// =============================================================================

/// Global Nintendo Switch gamepad & physical keyboard shortcuts mapping
Map<ShortcutActivator, Intent> get switchGamepadShortcuts => const {
      // Ⓐ Button / Select / Enter -> Confirm / Activate
      SingleActivator(LogicalKeyboardKey.gameButtonA): GamepadConfirmIntent(),
      SingleActivator(LogicalKeyboardKey.select): GamepadConfirmIntent(),
      SingleActivator(LogicalKeyboardKey.enter): GamepadConfirmIntent(),
      SingleActivator(LogicalKeyboardKey.numpadEnter): GamepadConfirmIntent(),

      // Ⓑ Button / Escape / Backspace -> Back / Dismiss
      SingleActivator(LogicalKeyboardKey.gameButtonB): GamepadBackIntent(),
      SingleActivator(LogicalKeyboardKey.escape): GamepadBackIntent(),
      SingleActivator(LogicalKeyboardKey.backspace): GamepadBackIntent(),

      // Ⓧ Button -> Quick Auto-Fill / Secondary Action
      SingleActivator(LogicalKeyboardKey.gameButtonX):
          GamepadQuickActionIntent(),

      // Ⓨ Button -> Browse / Pick File
      SingleActivator(LogicalKeyboardKey.gameButtonY): GamepadBrowseIntent(),

      // L / LB / L1 Bumper -> Previous Tab
      SingleActivator(LogicalKeyboardKey.gameButtonLeft1):
          GamepadPrevTabIntent(),

      // R / RB / R1 Bumper -> Next Tab
      SingleActivator(LogicalKeyboardKey.gameButtonRight1):
          GamepadNextTabIntent(),

      // Start / + Button / ContextMenu -> Run / Generate NSP
      SingleActivator(LogicalKeyboardKey.gameButtonStart): GamepadStartIntent(),
      SingleActivator(LogicalKeyboardKey.contextMenu): GamepadStartIntent(),

      // Minus / Select -> Toggle HUD
      SingleActivator(LogicalKeyboardKey.gameButtonSelect):
          GamepadToggleHudIntent(),
    };

// =============================================================================
// GAMEPAD ACTION IMPLEMENTATIONS
// =============================================================================

/// Action handler for Gamepad Confirm (A / Select / Enter)
class GamepadConfirmAction extends Action<GamepadConfirmIntent> {
  final VoidCallback? onConfirm;

  GamepadConfirmAction({this.onConfirm});

  @override
  Object? invoke(GamepadConfirmIntent intent) {
    if (onConfirm != null) {
      onConfirm!();
      return true;
    }
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context != null) {
      return Actions.maybeInvoke<ActivateIntent>(
        primaryFocus.context!,
        const ActivateIntent(),
      );
    }
    return null;
  }
}

/// Action handler for Gamepad Back (B / Escape / Backspace)
class GamepadBackAction extends Action<GamepadBackIntent> {
  final BuildContext? context;
  final VoidCallback? onBack;

  GamepadBackAction({this.context, this.onBack});

  @override
  Object? invoke(GamepadBackIntent intent) {
    if (onBack != null) {
      onBack!();
      return true;
    }

    final targetContext =
        context ?? FocusManager.instance.primaryFocus?.context;
    if (targetContext != null) {
      final navigator = Navigator.maybeOf(targetContext);
      if (navigator != null && navigator.canPop()) {
        navigator.maybePop();
        return true;
      }
      final primaryFocus = FocusManager.instance.primaryFocus;
      if (primaryFocus != null && primaryFocus.hasFocus) {
        final dismissed = Actions.maybeInvoke<DismissIntent>(
          primaryFocus.context!,
          const DismissIntent(),
        );
        if (dismissed != null) return dismissed;
        primaryFocus.unfocus();
        return true;
      }
    }
    return null;
  }
}

/// Action handler for Gamepad Quick Action (X button)
class GamepadQuickAction extends Action<GamepadQuickActionIntent> {
  final VoidCallback? onQuickAction;

  GamepadQuickAction({this.onQuickAction});

  @override
  Object? invoke(GamepadQuickActionIntent intent) {
    if (onQuickAction != null) {
      onQuickAction!();
      return true;
    }
    return null;
  }
}

/// Action handler for Gamepad Browse (Y button)
class GamepadBrowseAction extends Action<GamepadBrowseIntent> {
  final VoidCallback? onBrowse;

  GamepadBrowseAction({this.onBrowse});

  @override
  Object? invoke(GamepadBrowseIntent intent) {
    if (onBrowse != null) {
      onBrowse!();
      return true;
    }
    return null;
  }
}

/// Action handler for Gamepad Previous Tab (L button)
class GamepadPrevTabAction extends Action<GamepadPrevTabIntent> {
  final VoidCallback? onPrevTab;

  GamepadPrevTabAction({this.onPrevTab});

  @override
  Object? invoke(GamepadPrevTabIntent intent) {
    if (onPrevTab != null) {
      onPrevTab!();
      return true;
    }
    return null;
  }
}

/// Action handler for Gamepad Next Tab (R button)
class GamepadNextTabAction extends Action<GamepadNextTabIntent> {
  final VoidCallback? onNextTab;

  GamepadNextTabAction({this.onNextTab});

  @override
  Object? invoke(GamepadNextTabIntent intent) {
    if (onNextTab != null) {
      onNextTab!();
      return true;
    }
    return null;
  }
}

/// Action handler for Gamepad Run / Generate (+ button)
class GamepadStartAction extends Action<GamepadStartIntent> {
  final VoidCallback? onStart;

  GamepadStartAction({this.onStart});

  @override
  Object? invoke(GamepadStartIntent intent) {
    if (onStart != null) {
      onStart!();
      return true;
    }
    return null;
  }
}

/// Action handler for Gamepad Toggle HUD (- button)
class GamepadToggleHudAction extends Action<GamepadToggleHudIntent> {
  final VoidCallback? onToggleHud;

  GamepadToggleHudAction({this.onToggleHud});

  @override
  Object? invoke(GamepadToggleHudIntent intent) {
    if (onToggleHud != null) {
      onToggleHud!();
      return true;
    }
    return null;
  }
}

// =============================================================================
// FOCUS & GLOW DECORATION HELPER
// =============================================================================

/// Focus decoration builder for distinct neon glow styling
class SwitchFocusDecoration {
  static BoxDecoration glow({
    required bool isFocused,
    Color glowColor = AppTheme.switchCyan,
    BorderRadius? borderRadius,
    double borderWidth = 2.0,
    double blurRadius = 10.0,
    double spreadRadius = 2.0,
    Color? backgroundColor,
    Color? unfocusedBorderColor,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    if (!isFocused) {
      return BoxDecoration(
        color: backgroundColor,
        borderRadius: radius,
        border: Border.all(
          color: unfocusedBorderColor ?? Colors.transparent,
          width: borderWidth,
        ),
      );
    }

    return BoxDecoration(
      color: backgroundColor,
      borderRadius: radius,
      border: Border.all(color: glowColor, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.55),
          blurRadius: blurRadius,
          spreadRadius: spreadRadius,
        ),
      ],
    );
  }
}

// =============================================================================
// REUSABLE FOCUS GLOW CONTAINER
// =============================================================================

/// Wraps widgets with a responsive Nintendo Switch neon glow focus border
class SwitchFocusGlow extends StatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color glowColor;
  final BorderRadius? borderRadius;
  final double borderWidth;
  final VoidCallback? onActivate;
  final ValueChanged<bool>? onFocusChange;
  final bool isFocusable;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? unfocusedBorderColor;

  const SwitchFocusGlow({
    super.key,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.glowColor = AppTheme.switchCyan,
    this.borderRadius,
    this.borderWidth = 2.0,
    this.onActivate,
    this.onFocusChange,
    this.isFocusable = true,
    this.padding,
    this.backgroundColor,
    this.unfocusedBorderColor,
  });

  @override
  State<SwitchFocusGlow> createState() => _SwitchFocusGlowState();
}

class _SwitchFocusGlowState extends State<SwitchFocusGlow> {
  FocusNode? _internalNode;
  FocusNode get _effectiveNode =>
      widget.focusNode ?? (_internalNode ??= FocusNode());
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.isFocusable) {
      _effectiveNode.addListener(_handleFocusChange);
      _isFocused = _effectiveNode.hasFocus;
    }
  }

  @override
  void didUpdateWidget(SwitchFocusGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalNode)
          ?.removeListener(_handleFocusChange);
      if (widget.isFocusable) {
        _effectiveNode.addListener(_handleFocusChange);
        _isFocused = _effectiveNode.hasFocus;
      }
    }
  }

  @override
  void dispose() {
    _effectiveNode.removeListener(_handleFocusChange);
    _internalNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted && _isFocused != _effectiveNode.hasFocus) {
      setState(() {
        _isFocused = _effectiveNode.hasFocus;
      });
      widget.onFocusChange?.call(_isFocused);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isFocusable) {
      return widget.child;
    }

    final decoration = SwitchFocusDecoration.glow(
      isFocused: _isFocused,
      glowColor: widget.glowColor,
      borderRadius: widget.borderRadius,
      borderWidth: widget.borderWidth,
      backgroundColor: widget.backgroundColor,
      unfocusedBorderColor: widget.unfocusedBorderColor,
    );

    Widget container = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: decoration,
      child: widget.child,
    );

    // If activation callback is provided, attach Action handlers
    if (widget.onActivate != null) {
      return FocusableActionDetector(
        focusNode: _effectiveNode,
        autofocus: widget.autofocus,
        onFocusChange: (focused) {
          if (mounted && _isFocused != focused) {
            setState(() {
              _isFocused = focused;
            });
            widget.onFocusChange?.call(focused);
          }
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onActivate?.call();
              return true;
            },
          ),
          GamepadConfirmIntent: CallbackAction<GamepadConfirmIntent>(
            onInvoke: (_) {
              widget.onActivate?.call();
              return true;
            },
          ),
        },
        child: container,
      );
    }

    return container;
  }
}

// =============================================================================
// GAMEPAD SCOPE PROVIDER
// =============================================================================

/// InheritedWidget providing reactive updates when gamepad state changes
class _SwitchGamepadInheritedScope extends InheritedWidget {
  final SwitchGamepadState state;
  final bool isGamepadConnected;
  final bool isHudVisible;

  const _SwitchGamepadInheritedScope({
    required this.state,
    required this.isGamepadConnected,
    required this.isHudVisible,
    required super.child,
  });

  @override
  bool updateShouldNotify(_SwitchGamepadInheritedScope oldWidget) {
    return isGamepadConnected != oldWidget.isGamepadConnected ||
        isHudVisible != oldWidget.isHudVisible;
  }
}

/// Root Scope providing Gamepad Shortcuts, Actions, and Hardware Detection
class SwitchGamepadScope extends StatefulWidget {
  final Widget child;
  final bool autoDetect;
  final bool initialHudVisible;
  final bool? initialGamepadConnected;

  const SwitchGamepadScope({
    super.key,
    required this.child,
    this.autoDetect = true,
    this.initialHudVisible = true,
    this.initialGamepadConnected,
  });

  static SwitchGamepadState? of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_SwitchGamepadInheritedScope>();
    return inherited?.state ??
        context.findAncestorStateOfType<SwitchGamepadState>();
  }

  @override
  State<SwitchGamepadScope> createState() => SwitchGamepadState();
}

class SwitchGamepadState extends State<SwitchGamepadScope> {
  static const MethodChannel _channel = MethodChannel('io.n8.nspff/gamepad');

  bool _isGamepadConnected = false;
  bool _isHudVisible = true;

  bool get isGamepadActive => _isGamepadConnected;
  bool get isGamepadConnected => _isGamepadConnected;
  bool get isHudVisible => _isHudVisible;

  @override
  void initState() {
    super.initState();
    _isHudVisible = widget.initialHudVisible;
    _isGamepadConnected = widget.initialGamepadConnected ?? false;
    _initGamepadDetection();
    if (widget.autoDetect) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
  }

  Future<void> _initGamepadDetection() async {
    if (widget.initialGamepadConnected != null) return;
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onGamepadConnectionChanged') {
          final isConnected = (call.arguments as bool?) ?? false;
          if (mounted && _isGamepadConnected != isConnected) {
            setState(() {
              _isGamepadConnected = isConnected;
            });
          }
        }
      });
      final connected = await _channel.invokeMethod<bool>('isGamepadConnected');
      if (mounted && connected != null && _isGamepadConnected != connected) {
        setState(() {
          _isGamepadConnected = connected;
        });
      }
    } catch (_) {
      // Graceful fallback for testing or unsupported platforms
    }
  }

  @override
  void dispose() {
    if (widget.autoDetect) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    super.dispose();
  }

  static bool isGamepadKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.gameButtonC ||
        key == LogicalKeyboardKey.gameButtonX ||
        key == LogicalKeyboardKey.gameButtonY ||
        key == LogicalKeyboardKey.gameButtonZ ||
        key == LogicalKeyboardKey.gameButtonLeft1 ||
        key == LogicalKeyboardKey.gameButtonRight1 ||
        key == LogicalKeyboardKey.gameButtonLeft2 ||
        key == LogicalKeyboardKey.gameButtonRight2 ||
        key == LogicalKeyboardKey.gameButtonThumbLeft ||
        key == LogicalKeyboardKey.gameButtonThumbRight ||
        key == LogicalKeyboardKey.gameButtonStart ||
        key == LogicalKeyboardKey.gameButtonSelect ||
        key == LogicalKeyboardKey.gameButtonMode ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (isGamepadKey(event.logicalKey)) {
      if (!_isGamepadConnected && mounted) {
        setState(() {
          _isGamepadConnected = true;
        });
      }
    }
    return false; // Don't consume event
  }

  void setGamepadConnected(bool connected) {
    if (mounted && _isGamepadConnected != connected) {
      setState(() {
        _isGamepadConnected = connected;
      });
    }
  }

  void toggleHud() {
    if (mounted) {
      setState(() {
        _isHudVisible = !_isHudVisible;
      });
    }
  }

  void setHudVisible(bool visible) {
    if (mounted && _isHudVisible != visible) {
      setState(() {
        _isHudVisible = visible;
      });
    }
  }

  void _showGamepadFallback(String label) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('No gamepad action bound for $label on this screen.'),
        backgroundColor: AppTheme.switchYellow,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SwitchGamepadInheritedScope(
      state: this,
      isGamepadConnected: _isGamepadConnected,
      isHudVisible: _isHudVisible,
      child: Shortcuts(
        shortcuts: switchGamepadShortcuts,
        child: Actions(
          actions: {
            GamepadConfirmIntent: GamepadConfirmAction(),
            GamepadBackIntent: GamepadBackAction(context: context),
            GamepadQuickActionIntent: GamepadQuickAction(
                onQuickAction: () => _showGamepadFallback('Quick (X)')),
            GamepadBrowseIntent: GamepadBrowseAction(
                onBrowse: () => _showGamepadFallback('Browse (Y)')),
            GamepadStartIntent: GamepadStartAction(
                onStart: () => _showGamepadFallback('Start (+)')),
            GamepadToggleHudIntent:
                GamepadToggleHudAction(onToggleHud: toggleHud),
          },
          child: FocusScope(
            autofocus: true,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// GAMEPAD BUTTON BADGE & HUD LEGEND
// =============================================================================

/// Switch-styled circular or pill controller button badge
class SwitchControllerBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isBumper;
  final VoidCallback? onTap;

  const SwitchControllerBadge({
    super.key,
    required this.label,
    this.color = AppTheme.switchCyan,
    this.isBumper = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isBumper ? 5 : 4.5,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(isBumper ? 4 : 8),
        border: Border.all(color: color, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 3,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isBumper ? 4 : 8),
        child: badge,
      );
    }
    return badge;
  }
}

/// Dynamic Gamepad Button Legend HUD component for handhelds
class SwitchButtonLegend extends StatelessWidget {
  final VoidCallback? onPrevTab;
  final VoidCallback? onNextTab;
  final VoidCallback? onConfirm;
  final VoidCallback? onBack;
  final VoidCallback? onQuickAction;
  final VoidCallback? onBrowse;
  final VoidCallback? onStart;
  final int currentTabIndex;
  final bool? forceVisible;

  const SwitchButtonLegend({
    super.key,
    this.onPrevTab,
    this.onNextTab,
    this.onConfirm,
    this.onBack,
    this.onQuickAction,
    this.onBrowse,
    this.onStart,
    this.currentTabIndex = 0,
    this.forceVisible,
  });

  @override
  Widget build(BuildContext context) {
    final gamepadState = SwitchGamepadScope.of(context);
    final isConnected =
        forceVisible ?? (gamepadState?.isGamepadConnected ?? false);
    final isHudVisible = gamepadState?.isHudVisible ?? true;

    // Only come up if there is a gamepad connected and HUD is visible
    if (!isConnected || !isHudVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          top: BorderSide(color: AppTheme.cardBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SafeArea(
        top: false,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // [L] [R] Tabs
                Semantics(
                  label: 'L and R Bumpers: Switch Tabs',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchControllerBadge(
                        label: 'L',
                        color: AppTheme.switchRed,
                        isBumper: true,
                        onTap: onPrevTab,
                      ),
                      const SizedBox(width: 3),
                      SwitchControllerBadge(
                        label: 'R',
                        color: AppTheme.switchCyan,
                        isBumper: true,
                        onTap: onNextTab,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Tabs',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Ⓐ Select
                Semantics(
                  label: 'A Button: Select or Activate',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchControllerBadge(
                        label: 'A',
                        color: AppTheme.switchCyan,
                        onTap: onConfirm,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Select',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Ⓑ Back
                Semantics(
                  label: 'B Button: Back or Dismiss',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchControllerBadge(
                        label: 'B',
                        color: AppTheme.switchRed,
                        onTap: onBack,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Back',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Ⓧ Auto-Fill (relevant for forwarder tabs)
                if (currentTabIndex == 0 ||
                    currentTabIndex == 1 ||
                    currentTabIndex == 2) ...[
                  Semantics(
                    label: 'X Button: Auto-Fill',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchControllerBadge(
                          label: 'X',
                          color: AppTheme.switchYellow,
                          onTap: onQuickAction,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Auto-Fill',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Ⓨ Browse (also available on Batch tab for multi-ROM picker)
                if (currentTabIndex == 0 ||
                    currentTabIndex == 1 ||
                    currentTabIndex == 2) ...[
                  Semantics(
                    label: 'Y Button: Browse file',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchControllerBadge(
                          label: 'Y',
                          color: AppTheme.switchCyan,
                          onTap: onBrowse,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Browse',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // [+] Generate / Build
                Semantics(
                  label: 'Plus or Start Button: Generate NSP',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchControllerBadge(
                        label: '+',
                        color: AppTheme.switchGreen,
                        isBumper: true,
                        onTap: onStart,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Generate',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
