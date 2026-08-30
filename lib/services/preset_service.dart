import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/forwarder_config.dart';

class SavedPresetService {
  static const String _historyKey = 'forwarder_history_list';

  /// Save a forwarder config to history.
  static Future<void> addToHistory(ForwarderConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_historyKey) ?? [];

    final jsonStr = jsonEncode(config.toJson());
    current.insert(0, jsonStr); // latest first

    // Keep max 50 items
    if (current.length > 50) {
      current.removeLast();
    }

    await prefs.setStringList(_historyKey, current);
  }

  /// Get list of all saved forwarders in history.
  static Future<List<ForwarderConfig>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_historyKey) ?? [];
    final List<ForwarderConfig> list = [];
    for (var item in current) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        list.add(ForwarderConfig.fromJson(map));
      } catch (_) {}
    }
    return list;
  }

  /// Clear history.
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
