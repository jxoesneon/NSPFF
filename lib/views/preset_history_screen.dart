import 'package:flutter/material.dart';
import '../models/forwarder_config.dart';
import '../services/preset_service.dart';
import '../theme/switch_theme.dart';
import '../widgets/switch_card.dart';

class PresetHistoryScreen extends StatefulWidget {
  const PresetHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PresetHistoryScreen> createState() => _PresetHistoryScreenState();
}

class _PresetHistoryScreenState extends State<PresetHistoryScreen> {
  List<ForwarderConfig> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await SavedPresetService.getHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    await SavedPresetService.clearHistory();
    setState(() => _history = []);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.switchCyan));
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchCard(
              title: 'Generation History & Saved Profiles',
              subtitle: '${_history.length} previously created NSP forwarders',
              trailing: _history.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.delete_sweep, color: AppTheme.switchRed),
                      onPressed: _clearHistory,
                      tooltip: 'Clear History',
                    )
                  : null,
              child: _history.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No generated forwarders in history yet.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const Divider(color: AppTheme.cardBorder),
                      itemBuilder: (ctx, i) {
                        final item = _history[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: item.isRetroArch
                                ? AppTheme.switchCyan.withOpacity(0.2)
                                : AppTheme.switchRed.withOpacity(0.2),
                            child: Icon(
                              item.isRetroArch ? Icons.sports_esports : Icons.apps,
                              color: item.isRetroArch ? AppTheme.switchCyan : AppTheme.switchRed,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID: ${item.id}',
                                style: TextStyle(color: AppTheme.switchCyan, fontFamily: 'Monospace', fontSize: 11),
                              ),
                              Text(
                                item.isRetroArch ? 'ROM: ${item.romPath}' : 'NRO: ${item.nroPath}',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
