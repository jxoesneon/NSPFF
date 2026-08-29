class ProdKeys {
  final String rawText;
  final Map<String, String> keysMap;

  ProdKeys({
    required this.rawText,
    required this.keysMap,
  });

  factory ProdKeys.parse(String content) {
    final Map<String, String> map = {};
    final lines = content.split('\n');
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith(';')) {
        continue;
      }
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final keyName = parts[0].trim();
        final keyValue = parts.sublist(1).join('=').trim().replaceAll(' ', '');
        map[keyName] = keyValue;
      }
    }
    return ProdKeys(rawText: content, keysMap: map);
  }

  bool get isValid => keysMap.isNotEmpty && (hasHeaderKey || hasSdSeed || hasKeyAreaKey);

  bool get hasHeaderKey => keysMap.containsKey('header_key');
  bool get hasSdSeed => keysMap.containsKey('sd_seed');
  bool get hasTitleKdk => keysMap.containsKey('titlekdk_00');
  bool get hasKeyAreaKey => keysMap.keys.any((k) => k.startsWith('key_area_key_'));

  String? getKey(String keyName) => keysMap[keyName];

  List<String> get missingRecommendedKeys {
    final List<String> missing = [];
    if (!hasHeaderKey) missing.add('header_key');
    if (!hasSdSeed) missing.add('sd_seed');
    if (!hasTitleKdk) missing.add('titlekdk_00');
    if (!hasKeyAreaKey) missing.add('key_area_key_application_00');
    return missing;
  }
}
