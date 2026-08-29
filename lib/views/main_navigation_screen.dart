import 'package:flutter/material.dart';
import '../services/keys_service.dart';
import '../theme/switch_theme.dart';
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
                fontSize: 19,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SwitchTheme.switchCyan.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: SwitchTheme.switchCyan, width: 0.8),
              ),
              child: const Text(
                'FAST FORWARD',
                style: TextStyle(
                  color: SwitchTheme.switchCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Key Status Pill
          GestureDetector(
            onTap: () {
              _tabController.animateTo(3); // Go to Keys tab
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _hasValidKeys ? SwitchTheme.switchGreen.withOpacity(0.15) : SwitchTheme.switchRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _hasValidKeys ? SwitchTheme.switchGreen : SwitchTheme.switchRed,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasValidKeys ? Icons.vpn_key : Icons.vpn_key_off,
                    size: 14,
                    color: _hasValidKeys ? SwitchTheme.switchGreen : SwitchTheme.switchRed,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _hasValidKeys ? 'KEYS READY' : 'KEYS NEEDED',
                    style: TextStyle(
                      color: _hasValidKeys ? SwitchTheme.switchGreen : SwitchTheme.switchRed,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
    );
  }
}
