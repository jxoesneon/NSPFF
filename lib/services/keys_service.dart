// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prod_keys.dart';

/// Service responsible for managing cryptographic `prod.keys` securely.
///
/// Uses [FlutterSecureStorage] with Android Keystore-backed encryption
/// and iOS Keychain-backed encryption. Automatically migrates legacy
/// plaintext keys from [SharedPreferences] on initialization.
///
/// The plaintext in-memory `_testFallback` map is only used when
/// [_forceFallback] is enabled for headless unit tests; it is never
/// populated in production.
class KeysService extends ChangeNotifier {
  static const String _keysStorageKey = 'saved_prod_keys_text';

  /// Modern Android secure-storage options.
  ///
  /// `resetOnError` is disabled to prevent silent data loss when the
  /// Android Keystore is reset. The deprecated `encryptedSharedPreferences`
  /// flag is no longer used.
  static const AndroidOptions _androidOptions = AndroidOptions(
    resetOnError: false,
  );

  static FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  /// In-memory fallback map for unit test and headless environments only.
  ///
  /// This map is **not** populated in production; it is only used when
  /// [_forceFallback] is `true`.
  static final Map<String, String> _testFallback = <String, String>{};
  static bool _forceFallback = false;

  ProdKeys? _currentKeys;
  bool _isLoaded = false;

  ProdKeys? get currentKeys => _currentKeys;
  bool get isLoaded => _isLoaded;
  bool get hasValidKeys => _currentKeys != null && _currentKeys!.isValid;

  /// Exposed Android options for diagnostic / verification purposes.
  static AndroidOptions get androidOptions => _androidOptions;

  /// Set a mock [FlutterSecureStorage] for testing.
  @visibleForTesting
  static void setMockStorage(FlutterSecureStorage? mock) {
    _storage = mock ??
        const FlutterSecureStorage(
          aOptions: _androidOptions,
        );
  }

  /// Force use of in-memory fallback (e.g. to simulate headless runner).
  @visibleForTesting
  static void setForceFallback(bool force) {
    _forceFallback = force;
  }

  /// Clear in-memory test fallback map.
  @visibleForTesting
  static void clearTestFallback() {
    _testFallback.clear();
  }

  /// Write securely to Keystore-backed storage.
  ///
  /// In test mode ([_forceFallback] `true`) the value is written to
  /// [_testFallback]. In production it is written to secure storage only.
  static Future<void> _writeSecure(String key, String value) async {
    if (_forceFallback) {
      _testFallback[key] = value;
      return;
    }
    await _storage.write(
      key: key,
      value: value,
      aOptions: _androidOptions,
    );
  }

  /// Read securely from Keystore-backed storage.
  ///
  /// In test mode ([_forceFallback] `true`) the value is read from
  /// [_testFallback]. In production the plaintext fallback map is never used;
  /// plugin exceptions return `null` instead of leaking cached key material.
  static Future<String?> _readSecure(String key) async {
    if (_forceFallback) {
      return _testFallback[key];
    }
    try {
      return await _storage.read(
        key: key,
        aOptions: _androidOptions,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Delete securely from Keystore-backed storage.
  ///
  /// In test mode ([_forceFallback] `true`) the value is removed from
  /// [_testFallback]. In production the fallback map is also cleared on
  /// explicit delete to avoid leaving plaintext behind.
  static Future<void> _deleteSecure(String key) async {
    _testFallback.remove(key);
    if (_forceFallback) {
      return;
    }
    try {
      await _storage.delete(
        key: key,
        aOptions: _androidOptions,
      );
    } on MissingPluginException {
      // Already removed from fallback.
    } on PlatformException {
      // Already removed from fallback.
    }
  }

  /// Initialize and load keys from secure storage.
  ///
  /// Backward compatibility:
  /// Checks secure storage first. If not found, checks legacy [SharedPreferences].
  /// If found in legacy storage, automatically migrates to [FlutterSecureStorage]
  /// and removes the plaintext keys from [SharedPreferences].
  Future<void> init() async {
    _currentKeys = await loadKeys();
    _isLoaded = true;
    notifyListeners();
  }

  /// Save raw prod.keys content to persistent secure storage.
  Future<void> saveKeys(String rawContent) async {
    await saveRawKeys(rawContent);
    _currentKeys = ProdKeys.parse(rawContent);
    notifyListeners();
  }

  /// Clear saved keys from persistent secure storage and memory.
  Future<void> clearKeys() async {
    await clearRawKeys();
    _currentKeys = null;
    notifyListeners();
  }

  /// Static helper to save raw keys directly to secure storage.
  /// Also ensures legacy plaintext storage is purged.
  static Future<bool> saveRawKeys(String rawContent) async {
    await _writeSecure(_keysStorageKey, rawContent);
    // Purge legacy plaintext storage if present
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keysStorageKey);
    return true;
  }

  /// Static helper to clear keys from secure storage and legacy storage.
  static Future<bool> clearRawKeys() async {
    await _deleteSecure(_keysStorageKey);
    _testFallback.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keysStorageKey);
    return true;
  }

  /// Retrieve saved prod.keys from secure storage.
  ///
  /// Automatically migrates legacy [SharedPreferences] to [FlutterSecureStorage]
  /// if legacy keys exist and secure storage is empty.
  static Future<ProdKeys?> loadKeys() async {
    String? raw = await _readSecure(_keysStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      // Check legacy SharedPreferences for backward compatibility migration
      final prefs = await SharedPreferences.getInstance();
      final legacyRaw = prefs.getString(_keysStorageKey);
      if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
        // Automatically migrate to FlutterSecureStorage
        await _writeSecure(_keysStorageKey, legacyRaw);
        // Purge plaintext from SharedPreferences
        await prefs.remove(_keysStorageKey);
        raw = legacyRaw;
      }
    }

    if (raw == null || raw.trim().isEmpty) return null;
    return ProdKeys.parse(raw);
  }

  /// Loads the raw, unparsed `prod.keys` text from secure storage.
  ///
  /// This is intended for the keys editor UI and is not cached; the raw text
  /// is read on demand and immediately discarded by the caller.
  static Future<String?> loadRawText() => _readSecure(_keysStorageKey);
}
