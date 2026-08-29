import 'package:flutter/material.dart';
import '../services/keys_service.dart';
import '../theme/switch_theme.dart';
import '../widgets/switch_pill_badge.dart';
import 'batch_generator_screen.dart';
import 'guide_screen.dart';
import 'keys_manager_screen.dart';
import 'nro_forwarder_screen.dart';
import 'preset_history_screen.dart';
import 'retroarch_forwarder_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasValidKeys = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _checkKeys();
  }

  Future<void> _checkKeys() async {
    final keys = await KeysService.loadKeys();
    setState(() {
      _hasValidKeys = keys != null && keys.isValid;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Joy-Con Red Accent
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: SwitchTheme.switchRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            // Joy-Con Cyan Accent
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: SwitchTheme.switchCyan,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'NSPFF',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            const SwitchPillBadge(
              label: 'FAST FORWARD',
              color: SwitchTheme.switchCyan,
            ),
          ],
        ),
        actions: [
          // Key Status Pill
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SwitchPillBadge(
              label: _hasValidKeys ? 'KEYS READY' : 'KEYS NEEDED',
              color: _hasValidKeys ? SwitchTheme.switchGreen : SwitchTheme.switchRed,
              icon: _hasValidKeys ? Icons.vpn_key : Icons.vpn_key_off,
              onTap: () => _tabController.animateTo(3),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: SwitchTheme.switchCyan,
          indicatorWeight: 3,
          labelColor: SwitchTheme.switchCyan,
          unselectedLabelColor: SwitchTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.apps, size: 20), text: 'NRO Apps'),
            Tab(icon: Icon(Icons.sports_esports, size: 20), text: 'RetroArch'),
            Tab(icon: Icon(Icons.dynamic_feed, size: 20), text: 'Batch ROMs'),
            Tab(icon: Icon(Icons.key, size: 20), text: 'Keys Manager'),
            Tab(icon: Icon(Icons.history, size: 20), text: 'History'),
            Tab(icon: Icon(Icons.help_outline, size: 20), text: 'Guide & Parity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          NroForwarderScreen(),
          RetroArchForwarderScreen(),
          BatchGeneratorScreen(),
          KeysManagerScreen(),
          PresetHistoryScreen(),
          GuideScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 36,
        color: SwitchTheme.cardBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: SwitchTheme.switchCyan),
                SizedBox(width: 6),
                Text('Ⓐ Select / Autodetect', style: TextStyle(color: SwitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
            Row(
              children: [
                Icon(Icons.change_circle_outlined, size: 12, color: SwitchTheme.switchRed),
                SizedBox(width: 4),
                Text('Ⓑ Back / Clear', style: TextStyle(color: SwitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
            Row(
              children: [
                Icon(Icons.add_circle_outline, size: 12, color: SwitchTheme.switchGreen),
                SizedBox(width: 4),
                Text('⊕ Build NSP', style: TextStyle(color: SwitchTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
