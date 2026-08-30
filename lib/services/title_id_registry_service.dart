// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Validation result produced by [TitleIdRegistryService.validateTitleId].
class TitleIdValidationResult {
  /// Whether the ID is valid for forwarder usage.
  /// False if formatting is invalid, reserved, or if the ID is a retail or
  /// out-of-range Title ID without an explicit [allowUnsafe] override.
  final bool isValid;

  /// Whether the ID collides with reserved Nintendo System Title ranges
  /// (System Modules, System Data, or System Applets).
  final bool isReservedSystem;

  /// Whether the ID collides with the retail game range (starts with 0100).
  final bool isRetailConflict;

  /// Whether the ID is already registered to a forwarder on this device.
  final bool isRegistered;

  /// Human-readable diagnostic warning or error message explaining the conflict.
  final String? warningMessage;

  /// Whether the Title ID falls within the standard homebrew forwarder range:
  /// 0x0500000000000000 - 0x05FFFFFFFFFFFFFF.
  final bool isInHomebrewRange;

  const TitleIdValidationResult({
    required this.isValid,
    required this.isReservedSystem,
    required this.isRetailConflict,
    required this.isRegistered,
    this.warningMessage,
    this.isInHomebrewRange = false,
  });

  /// Whether any warning or error message is present.
  bool get hasWarning => warningMessage != null;

  /// Whether the ID is completely safe to use without any warnings or conflicts.
  bool get isSafe =>
      isValid &&
      isInHomebrewRange &&
      !isReservedSystem &&
      !isRetailConflict &&
      !isRegistered;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TitleIdValidationResult &&
          runtimeType == other.runtimeType &&
          isValid == other.isValid &&
          isReservedSystem == other.isReservedSystem &&
          isRetailConflict == other.isRetailConflict &&
          isRegistered == other.isRegistered &&
          warningMessage == other.warningMessage &&
          isInHomebrewRange == other.isInHomebrewRange;

  @override
  int get hashCode => Object.hash(
        isValid,
        isReservedSystem,
        isRetailConflict,
        isRegistered,
        warningMessage,
        isInHomebrewRange,
      );

  @override
  String toString() =>
      'TitleIdValidationResult(isValid: $isValid, isReservedSystem: $isReservedSystem, '
      'isRetailConflict: $isRetailConflict, isRegistered: $isRegistered, '
      'warningMessage: $warningMessage, isInHomebrewRange: $isInHomebrewRange)';
}

/// Service managing registered forwarder Title IDs and enforcing the
/// Title ID Conflict Guard against reserved Nintendo System and Retail titles.
class TitleIdRegistryService {
  static const String _registeredIdsKey = 'registered_title_ids';

  // System Modules: 0100000000000000 - 0100000000000045
  static final BigInt _systemModulesStart =
      BigInt.parse('0100000000000000', radix: 16);
  static final BigInt _systemModulesEnd =
      BigInt.parse('0100000000000045', radix: 16);

  // System Data: 0100000000000800 - 0100000000000830
  static final BigInt _systemDataStart =
      BigInt.parse('0100000000000800', radix: 16);
  static final BigInt _systemDataEnd =
      BigInt.parse('0100000000000830', radix: 16);

  // System Applets: 0100000000001000 - 0100000000001015
  static final BigInt _systemAppletsStart =
      BigInt.parse('0100000000001000', radix: 16);
  static final BigInt _systemAppletsEnd =
      BigInt.parse('0100000000001015', radix: 16);

  // Valid Homebrew Forwarder Range: 0x0500000000000000 - 0x05FFFFFFFFFFFFFF
  static final BigInt _homebrewRangeStart =
      BigInt.parse('0500000000000000', radix: 16);
  static final BigInt _homebrewRangeEnd =
      BigInt.parse('05FFFFFFFFFFFFFF', radix: 16);

  static final RegExp _hex16Regex = RegExp(r'^[0-9A-Fa-f]{16}$');

  // In-memory cache for fast synchronous validation in UI widgets
  static final Set<String> _cachedRegisteredIds = <String>{};

  /// Clean raw Title ID string by removing hex prefixes, whitespace, and converting to uppercase.
  static String cleanTitleId(String id) {
    return id
        .trim()
        .replaceAll('0x', '')
        .replaceAll('0X', '')
        .replaceAll(' ', '')
        .toUpperCase();
  }

  /// Populate or inspect registered IDs in the in-memory cache for testing.
  @visibleForTesting
  static void setRegisteredCache(Iterable<String> ids) {
    _cachedRegisteredIds.clear();
    _cachedRegisteredIds.addAll(ids.map((e) => cleanTitleId(e)));
  }

  /// Reset the in-memory cache.
  @visibleForTesting
  static void resetCache() {
    _cachedRegisteredIds.clear();
  }

  /// Comprehensive Title ID Conflict Guard validation.
  ///
  /// Checks for:
  /// 1. Valid 16-hex digit format
  /// 2. Reserved Nintendo System Titles (System Modules, System Data, System Applets)
  /// 3. Retail Game Base Range (0100...)
  /// 4. Valid Homebrew Forwarder Range (0x0500000000000000 - 0x05FFFFFFFFFFFFFF)
  /// 5. Existing registered Title IDs on device
  ///
  /// Set [allowUnsafe] to `true` to treat retail or out-of-range IDs as valid
  /// after the user has explicitly acknowledged the warning. Reserved system
  /// IDs are never valid, regardless of [allowUnsafe].
  static TitleIdValidationResult validateTitleId(
    String id, {
    Iterable<String>? registeredIds,
    bool allowUnsafe = false,
  }) {
    final clean = cleanTitleId(id);

    if (clean.isEmpty) {
      return const TitleIdValidationResult(
        isValid: false,
        isReservedSystem: false,
        isRetailConflict: false,
        isRegistered: false,
        warningMessage: 'Title ID cannot be empty.',
      );
    }

    if (!_hex16Regex.hasMatch(clean)) {
      return TitleIdValidationResult(
        isValid: false,
        isReservedSystem: false,
        isRetailConflict: false,
        isRegistered: false,
        warningMessage:
            'Invalid Title ID format. Must be exactly 16 hexadecimal characters (found ${clean.length}).',
      );
    }

    final BigInt? numericId = BigInt.tryParse(clean, radix: 16);
    if (numericId == null) {
      return const TitleIdValidationResult(
        isValid: false,
        isReservedSystem: false,
        isRetailConflict: false,
        isRegistered: false,
        warningMessage: 'Invalid hexadecimal representation.',
      );
    }

    // Reserved Nintendo System Titles checks
    final bool isSystemModule =
        numericId >= _systemModulesStart && numericId <= _systemModulesEnd;
    final bool isSystemData =
        numericId >= _systemDataStart && numericId <= _systemDataEnd;
    final bool isSystemApplet =
        numericId >= _systemAppletsStart && numericId <= _systemAppletsEnd;

    final bool isReservedSystem =
        isSystemModule || isSystemData || isSystemApplet;

    // Retail Game Base Range: 0100... (outside reserved system)
    final bool isRetailConflict = clean.startsWith('0100') && !isReservedSystem;

    // Valid Homebrew Range: 0x0500000000000000 - 0x05FFFFFFFFFFFFFF
    final bool isInHomebrewRange =
        numericId >= _homebrewRangeStart && numericId <= _homebrewRangeEnd;

    // Check device registered forwarders
    final registeredSet = registeredIds != null
        ? registeredIds.map((e) => cleanTitleId(e)).toSet()
        : _cachedRegisteredIds;
    final bool isRegistered = registeredSet.contains(clean);

    String? warning;
    if (isSystemModule) {
      warning =
          'CRITICAL: Title ID $clean collides with a reserved Nintendo System Module (0100000000000000 - 0100000000000045). Overwriting this ID will crash Horizon OS!';
    } else if (isSystemData) {
      warning =
          'CRITICAL: Title ID $clean collides with a reserved Nintendo System Data archive (0100000000000800 - 0100000000000830). Overwriting this ID will corrupt Switch OS!';
    } else if (isSystemApplet) {
      warning =
          'CRITICAL: Title ID $clean collides with a reserved Nintendo System Applet (0100000000001000 - 0100000000001015). Overwriting this ID will cause system applet failures!';
    } else if (isRegistered && isRetailConflict) {
      warning =
          'Title ID $clean is already registered and starts with 0100 (reserved for official retail games).';
    } else if (isRegistered) {
      warning =
          'Title ID $clean is already in use by another forwarder on this device.';
    } else if (isRetailConflict) {
      warning =
          'Warning: 0100... Title IDs are reserved for official retail games. Use 05... for homebrew forwarders to avoid collisions.';
    } else if (!isInHomebrewRange) {
      warning =
          'Warning: Title ID $clean falls outside the recommended homebrew forwarder range (0500000000000000 - 05FFFFFFFFFFFFFF).';
    }

    // Reserved system collisions are strictly forbidden and cannot be valid forwarders.
    // Retail and out-of-range IDs are invalid unless the caller explicitly
    // overrides after presenting a clear warning.
    final bool isValid =
        !isReservedSystem && (isInHomebrewRange || allowUnsafe);

    return TitleIdValidationResult(
      isValid: isValid,
      isReservedSystem: isReservedSystem,
      isRetailConflict: isRetailConflict,
      isRegistered: isRegistered,
      warningMessage: warning,
      isInHomebrewRange: isInHomebrewRange,
    );
  }

  /// Asynchronously validate a Title ID by querying persistent storage for registered IDs.
  static Future<TitleIdValidationResult> validateTitleIdAsync(String id) async {
    final registered = await getRegisteredTitleIds();
    return validateTitleId(id, registeredIds: registered);
  }

  /// Check if a Title ID is already in use by a generated forwarder.
  static Future<bool> isTitleIdRegistered(String id) async {
    final list = await getRegisteredTitleIds();
    final cleanId = cleanTitleId(id);
    return list.contains(cleanId);
  }

  /// Register a Title ID as used.
  ///
  /// Rejects reserved system, retail, out-of-range, or already-registered IDs.
  /// Only safe homebrew forwarder IDs in the 05... range are accepted.
  static Future<void> registerTitleId(String id, String title) async {
    final validation = validateTitleId(id);
    if (!validation.isSafe) {
      throw ArgumentError(
        'Cannot register unsafe Title ID: ${validation.warningMessage ?? 'unknown conflict'}',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_registeredIdsKey) ?? [];
    final cleanId = cleanTitleId(id);
    if (!list.contains(cleanId)) {
      list.add(cleanId);
      await prefs.setStringList(_registeredIdsKey, list);
    }
    _cachedRegisteredIds.add(cleanId);
  }

  /// Get all registered Title IDs.
  static Future<List<String>> getRegisteredTitleIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_registeredIdsKey) ?? [];
    final cleaned = list.map((e) => cleanTitleId(e)).toList();
    _cachedRegisteredIds.clear();
    _cachedRegisteredIds.addAll(cleaned);
    return cleaned;
  }

  /// Clear Title ID registry.
  static Future<void> clearRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_registeredIdsKey);
    _cachedRegisteredIds.clear();
  }
}
