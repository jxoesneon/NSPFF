import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconic_morph/iconic_morph.dart';
import '../theme/switch_gamepad_navigation.dart';
import '../services/file_saver_service.dart';
import '../services/keys_service.dart';
import '../theme/switch_theme.dart';
import '../theme/switch_icons.dart';
import '../widgets/network_install_dialog.dart';
import 'batch_generator_screen.dart';
import 'guide_screen.dart';
import 'keys_manager_screen.dart';
import 'nro_forwarder_screen.dart';
import 'preset_history_screen.dart';
import 'retroarch_forwarder_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _previousTab() {
    final nextIndex = (_tabController.index - 1 + _tabController.length) %
        _tabController.length;
    _tabController.animateTo(nextIndex);
  }

  void _nextTab() {
    final nextIndex = (_tabController.index + 1) % _tabController.length;
    _tabController.animateTo(nextIndex);
  }

  void _invokeGamepadIntent<T extends Intent>(T intent) {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context != null) {
      Actions.maybeInvoke<T>(
        primaryFocus.context!,
        intent,
      );
    }
  }

  Future<void> _showStorageSettingsModal() async {
    final currentFolder = await FileSaverService.getDisplayTargetFolder();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: AppTheme.switchCyan, size: 24),
            SizedBox(width: 10),
            Text('Storage Destination',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configured target folder for generated NSP files (Android SAF & Scoped Storage):',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.inputBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Text(
                currentFolder,
                style: AppTheme.monoStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FileSaverService.clearSavedTargetFolder();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Storage destination reset to default.'),
                    backgroundColor: AppTheme.switchCyan,
                  ),
                );
              }
            },
            child: const Text('RESET TO DEFAULT',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final picked = await FileSaverService.pickTargetFolder();
              if (picked != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Output folder set to: $picked'),
                    backgroundColor: AppTheme.switchGreen,
                  ),
                );
              }
            },
            child: const Text('CHOOSE FOLDER',
                style: TextStyle(color: AppTheme.switchCyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keysService = context.watch<KeysService>();
    final hasValidKeys = keysService.hasValidKeys;

    return Actions(
      actions: {
        GamepadPrevTabIntent: GamepadPrevTabAction(onPrevTab: _previousTab),
        GamepadNextTabIntent: GamepadNextTabAction(onNextTab: _nextTab),
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 40,
            title: const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fast Forward Chevrons ">>" in Joy-Con colors
                  SizedBox(
                    width: 26,
                    height: 24,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Positioned(
                          left: 0,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.switchRed,
                            size: 24,
                          ),
                        ),
                        Positioned(
                          left: 8,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.switchCyan,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // App Title & Subtext
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NSPFF',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1.0,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'FAST FORWARD',
                        style: TextStyle(
                          color: AppTheme.switchCyan,
                          fontWeight: FontWeight.w700,
                          fontSize: 8.5,
                          letterSpacing: 1.4,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Wireless Console Installer',
                icon: const Icon(Icons.wifi_tethering,
                    color: AppTheme.switchCyan, size: 20),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => NetworkInstallDialog.show(context),
              ),
              IconButton(
                tooltip: 'Storage Destination',
                icon: const Icon(Icons.folder_outlined,
                    color: AppTheme.switchCyan, size: 20),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: _showStorageSettingsModal,
              ),
              // Key Status Pill (stays expanded for first few seconds, then morphs to icon)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: _MorphingKeyStatusPill(
                    hasValidKeys: hasValidKeys,
                    onTap: () => _tabController.animateTo(3),
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              indicatorColor: AppTheme.switchCyan,
              indicatorWeight: 3,
              labelColor: AppTheme.switchCyan,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(icon: Icon(Icons.apps, size: 20), text: 'NRO Apps'),
                Tab(
                    icon: Icon(Icons.sports_esports, size: 20),
                    text: 'RetroArch'),
                Tab(
                    icon: Icon(Icons.dynamic_feed, size: 20),
                    text: 'Batch ROMs'),
                Tab(icon: Icon(Icons.key, size: 20), text: 'Keys Manager'),
                Tab(icon: Icon(Icons.history, size: 20), text: 'History'),
                Tab(
                    icon: Icon(Icons.help_outline, size: 20),
                    text: 'Guide & Parity'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              const NroForwarderScreen(),
              const RetroArchForwarderScreen(),
              const BatchGeneratorScreen(),
              const KeysManagerScreen(),
              const PresetHistoryScreen(),
              const GuideScreen(),
            ],
          ),
          bottomNavigationBar: SwitchButtonLegend(
            onPrevTab: _previousTab,
            onNextTab: _nextTab,
            currentTabIndex: _tabController.index,
            onConfirm: () {
              final primaryFocus = FocusManager.instance.primaryFocus;
              if (primaryFocus != null && primaryFocus.context != null) {
                Actions.maybeInvoke<ActivateIntent>(
                  primaryFocus.context!,
                  const ActivateIntent(),
                );
              }
            },
            onBack: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            },
            onQuickAction: () => _invokeGamepadIntent<GamepadQuickActionIntent>(
              const GamepadQuickActionIntent(),
            ),
            onBrowse: () => _invokeGamepadIntent<GamepadBrowseIntent>(
              const GamepadBrowseIntent(),
            ),
            onStart: () => _invokeGamepadIntent<GamepadStartIntent>(
              const GamepadStartIntent(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Key Status indicator that stays expanded for the first few seconds
/// and then morphs into a compact circular icon button
class _MorphingKeyStatusPill extends StatefulWidget {
  final bool hasValidKeys;
  final VoidCallback onTap;

  const _MorphingKeyStatusPill({
    required this.hasValidKeys,
    required this.onTap,
  });

  @override
  State<_MorphingKeyStatusPill> createState() => _MorphingKeyStatusPillState();
}

class _MorphingKeyStatusPillState extends State<_MorphingKeyStatusPill> {
  bool _isExpanded = true;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    _startCollapseTimer();
  }

  @override
  void didUpdateWidget(covariant _MorphingKeyStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasValidKeys != widget.hasValidKeys) {
      _collapseTimer?.cancel();
      setState(() {
        _isExpanded = true;
      });
      _startCollapseTimer();
    }
  }

  void _startCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor =
        widget.hasValidKeys ? AppTheme.switchGreen : AppTheme.switchYellow;
    final label = widget.hasValidKeys ? 'KEYS READY' : 'KEYS NEEDED';

    final Widget iconWidget = IconGeometry.resolver != null
        ? IconicMorph(
            SwitchIcons.keyOff,
            SwitchIcons.key,
            autoplay: widget.hasValidKeys,
            plan: const IconMorphPlan(duration: Duration(milliseconds: 400)),
            size: 15,
            color: statusColor,
          )
        : Icon(
            widget.hasValidKeys ? Icons.vpn_key : Icons.vpn_key_off,
            size: 15,
            color: statusColor,
          );

    final pillContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                axis: Axis.horizontal,
                alignment: Alignment.centerLeft,
                sizeFactor: animation,
                child: child,
              ),
            );
          },
          child: _isExpanded
              ? Row(
                  key: const ValueKey('expanded_label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('collapsed_label')),
        ),
      ],
    );

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        showDuration: const Duration(seconds: 5),
        waitDuration: Duration.zero,
        child: InkWell(
          onTap: () {
            if (!_isExpanded) {
              setState(() {
                _isExpanded = true;
              });
              _startCollapseTimer();
            } else {
              widget.onTap();
            }
          },
          onLongPress: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            height: 32,
            padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 10 : 7,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.25),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: pillContent,
          ),
        ),
      ),
    );
  }
}
