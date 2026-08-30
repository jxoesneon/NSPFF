// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

/// Parsed representation of a Nintendo Switch `prod.keys` file.
///
/// The original raw text is not retained after parsing; only the extracted
/// key-value pairs are stored in memory to reduce exposure of cryptographic
/// material.
class ProdKeys {
  final Map<String, String> keysMap;

  ProdKeys({
    required this.keysMap,
  });

  factory ProdKeys.parse(String content) {
    final Map<String, String> map = {};
    final lines = content.split('\n');
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('#') ||
          trimmed.startsWith(';')) {
        continue;
      }
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final keyName = parts[0].trim();
        final keyValue = parts.sublist(1).join('=').trim().replaceAll(' ', '');
        map[keyName] = keyValue;
      }
    }
    return ProdKeys(keysMap: map);
  }

  /// Whether the parsed keys satisfy the same minimum requirements as
  /// [HealthDiagnosticService]: at least one key is present, plus
  /// `header_key`, `sd_seed`, and `titlekdk_00`.
  bool get isValid =>
      keysMap.isNotEmpty && hasHeaderKey && hasSdSeed && hasTitleKdk;

  bool get hasHeaderKey => keysMap.containsKey('header_key');
  bool get hasSdSeed => keysMap.containsKey('sd_seed');
  bool get hasTitleKdk => keysMap.containsKey('titlekdk_00');
  bool get hasTitleKek => keysMap.containsKey('titlekek_00');
  bool get hasKeyAreaKey =>
      keysMap.keys.any((k) => k.startsWith('key_area_key_'));

  String? getKey(String keyName) => keysMap[keyName];

  List<String> get missingRecommendedKeys {
    final List<String> missing = [];
    if (!hasHeaderKey) missing.add('header_key');
    if (!hasSdSeed) missing.add('sd_seed');
    if (!hasTitleKdk && !hasTitleKek) missing.add('titlekdk_00');
    if (!hasKeyAreaKey) missing.add('key_area_key_application_00');
    return missing;
  }
}
