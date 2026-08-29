// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:shared_preferences/shared_preferences.dart';

class TitleIdRegistryService {
  static const String _registeredIdsKey = 'registered_title_ids';

  /// Check if a Title ID is already in use by a generated forwarder.
  static Future<bool> isTitleIdRegistered(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_registeredIdsKey) ?? [];
    final cleanId = id.replaceAll('0x', '').replaceAll(' ', '').toUpperCase();
    return list.contains(cleanId);
  }

  /// Register a Title ID as used.
  static Future<void> registerTitleId(String id, String title) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_registeredIdsKey) ?? [];
    final cleanId = id.replaceAll('0x', '').replaceAll(' ', '').toUpperCase();
    if (!list.contains(cleanId)) {
      list.add(cleanId);
      await prefs.setStringList(_registeredIdsKey, list);
    }
  }

  /// Get all registered Title IDs.
  static Future<List<String>> getRegisteredTitleIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_registeredIdsKey) ?? [];
  }

  /// Clear Title ID registry.
  static Future<void> clearRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_registeredIdsKey);
  }
}
