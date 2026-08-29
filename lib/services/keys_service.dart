import 'package:shared_preferences/shared_preferences.dart';
import '../models/prod_keys.dart';

class KeysService {
  static const String _keysStorageKey = 'saved_prod_keys_text';

  /// Save raw prod.keys content to persistent local storage.
  static Future<bool> saveKeys(String rawContent) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keysStorageKey, rawContent);
  }

  /// Retrieve saved prod.keys from local storage.
  static Future<ProdKeys?> loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keysStorageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return ProdKeys.parse(raw);
  }

  /// Clear saved keys.
  static Future<bool> clearKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_keysStorageKey);
  }
}
