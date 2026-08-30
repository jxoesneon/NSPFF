// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import '../models/forwarder_config.dart';

class ConfigExportImportService {
  /// Export list of forwarder configurations to a formatted JSON string backup.
  static String exportConfigsToJson(List<ForwarderConfig> configs) {
    final List<Map<String, dynamic>> jsonList =
        configs.map((c) => c.toJson()).toList();
    final Map<String, dynamic> payload = {
      'app': 'NSPFF',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'configs': jsonList,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Import forwarder configurations from a JSON backup string.
  static List<ForwarderConfig> importConfigsFromJson(String jsonContent) {
    final List<ForwarderConfig> results = [];
    try {
      final Map<String, dynamic> data =
          jsonDecode(jsonContent) as Map<String, dynamic>;
      if (data['configs'] is List) {
        final List<dynamic> list = data['configs'] as List<dynamic>;
        for (var item in list) {
          if (item is Map<String, dynamic>) {
            results.add(ForwarderConfig.fromJson(item));
          }
        }
      }
    } catch (_) {}
    return results;
  }
}
