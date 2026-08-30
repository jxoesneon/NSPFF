# NSPFF Safety & Security Council Audit Report

**Project:** `/Users/mey/NSPFF` — Flutter Android application for generating Nintendo Switch NSP forwarders and wireless installation.  
**Audit scope:** Cryptographic key handling, Title ID collision guard, Android scoped storage / SAF, network installation security, dependency posture, and security test coverage.  
**Auditor:** Ciel General Council — Safety & Security Council  
**Date:** 2026-08-30  

---

## 1. Scope & Methodology

The following source files, tests, and referenced models were reviewed:

- `lib/services/keys_service.dart`
- `lib/services/title_id_registry_service.dart`
- `lib/services/file_saver_service.dart`
- `lib/services/network_install_service.dart`
- `lib/services/preset_service.dart`
- `lib/services/health_diagnostic_service.dart`
- `lib/models/prod_keys.dart`
- `lib/models/forwarder_config.dart`
- `lib/widgets/title_id_input.dart`
- `lib/widgets/switch_text_field.dart`
- `lib/services/nsp_generator.dart`
- `lib/services/config_export_import_service.dart`
- `test/services/keys_service_secure_test.dart`
- `test/services/title_id_registry_service_test.dart`
- `test/services/file_saver_service_test.dart`
- `test/security/security_test.dart`
- `test/services/network_install_service_test.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/io/n8/nspff/MainActivity.kt`
- `android/app/build.gradle`
- `pubspec.yaml` / `pubspec.lock`

Validation performed:

- `flutter analyze --no-pub` — **No issues found**.
- Targeted `flutter test` runs for key security and Title-ID invariants — **All passed**:
  - `test/services/title_id_registry_service_test.dart`
  - `test/services/keys_service_secure_test.dart`
  - `test/security/security_test.dart`
- No source code was modified.

---

## 2. Executive Summary

**Overall Security Posture Score: 52 / 100**  
*Classification: Moderate, with one critical network-exposure finding and several high/medium platform-level weaknesses.*

### Strengths

- `prod.keys` are stored with `flutter_secure_storage` and legacy plaintext in `SharedPreferences` is automatically migrated and purged.
- `TitleIdRegistryService` correctly blocks the reserved Nintendo system-module, system-data, and system-applet ranges (`0100000000000000`–`0100000000001015`).
- Unit tests cover the Title-ID boundaries, key migration/eviction, and basic filename sanitization.
- `NspGenerator` sanitizes generated filenames before they reach the file system or network server.
- `MainActivity` exposes a minimal, non-security-sensitive gamepad method channel and has no exported deep-link receivers.

### Key Weaknesses

- The embedded HTTP server binds to **all IPv4 interfaces** (`0.0.0.0`) with **wildcard CORS**, exposing generated NSPs to the entire LAN and enabling cross-origin exfiltration from malicious websites.
- `FileSaverService` joins user-supplied filenames directly into target directories without sanitization, creating a path-traversal surface.
- The Android manifest is over-privileged (`MANAGE_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `READ_EXTERNAL_STORAGE`, `requestLegacyExternalStorage`) and **does not disable auto-backup** (`android:allowBackup` defaults to `true`).
- `KeysService` keeps a plaintext in-memory `_testFallback` cache of `prod.keys` even in production and falls back to it on plugin exceptions.
- Title ID validation is **advisory** for retail (`0100...`) and non-homebrew ranges; `isValid` is still `true`, so a user can still generate a forwarder that collides with retail games.

---

## 3. Detailed Findings

| Severity | Location (File:Line) | Defect | Impact | Remedy |
|----------|----------------------|--------|--------|----------|
| **CRITICAL** | `lib/services/network_install_service.dart:194,246-249` | Embedded HTTP server binds to `InternetAddress.anyIPv4` and sets `Access-Control-Allow-Origin: *` / `Access-Control-Allow-Headers: *`. | Any device on the same LAN (or public Wi-Fi) can enumerate and download registered NSPs. Wildcard CORS allows a malicious website visited by the user to read the same content via the local IP. | Bind to the selected LAN interface returned by `detectLocalIp()` (or loopback-only mode), remove wildcard CORS, and add a per-session random token or mDNS pairing secret. |
| **HIGH** | `lib/services/file_saver_service.dart:151` + `AndroidManifest.xml:6` | `saveNspFile` joins `filename` into the target directory with `p.join(dir.path, filename)` without validation. `MANAGE_EXTERNAL_STORAGE` is declared. | A caller passing `../../<path>` or an absolute filename can write outside the intended directory. Combined with broad all-files permission, arbitrary files may be overwritten. | Sanitize with `p.basename` and a whitelist before joining; remove `MANAGE_EXTERNAL_STORAGE` unless a documented all-files feature is required and granted via `Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`. |
| **HIGH** | `AndroidManifest.xml:4-7,13` + `lib/services/file_saver_service.dart:94-95` | Manifest declares `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `MANAGE_EXTERNAL_STORAGE`, and `requestLegacyExternalStorage="true"`. The service hardcodes `/storage/emulated/0/Download` and `/sdcard/Download`. | On Android 11+ (API 30–36) these paths are not writable without `MANAGE_EXTERNAL_STORAGE` being explicitly granted. The manifest is over-privileged and the runtime permission request is missing. | Reduce to `INTERNET` + SAF; use `MediaStore`/`Storage Access Framework` (`ACTION_OPEN_DOCUMENT_TREE`) for user-selected directories; drop legacy flags. |
| **MEDIUM** | `lib/services/keys_service.dart:31-34,67-84,87-106` | `_testFallback` map caches the **plaintext** raw `prod.keys` value after every successful write and is returned on `MissingPluginException` / `PlatformException`. | Cryptographic material persists in process memory for the app lifetime and may survive a Keystore reset. A debugger, rooted device, or memory dump can extract it. | Do not cache the decrypted key blob in a static map in production. If headless test fallback is required, guard it behind `kDebugMode` and/or clear it aggressively with `FillSecurity.delete`. |
| **MEDIUM** | `AndroidManifest.xml:9-14` (missing attr) + `lib/services/preset_service.dart:1-43` + `lib/services/title_id_registry_service.dart:259-263` | `android:allowBackup` is not set to `false`; forwarder history and registered Title IDs are stored in plaintext `SharedPreferences`. | Android Auto Backup may push app data (including generated history and configured target folders) to Google cloud, increasing disclosure and restore-to-other-device risk. | Set `android:allowBackup="false"` (or provide `fullBackupContent` rules excluding `shared_prefs`), and encrypt sensitive `SharedPreferences` with `encrypted_shared_preferences` or a similar wrapper. |
| **MEDIUM** | `lib/services/network_install_service.dart:195,244-283,514-528` | `idleTimeout = null` (or default none), no request-size limit, no concurrency/rate limit, and no `filename` basename check in `_serveNsp`. | Open connections can accumulate; large or repeated range requests can exhaust memory/CPU; an attacker-controlled filename can be registered and reflected into the HTML index. | Set an `idleTimeout`, cap `contentLength`, add a request rate limiter, and validate that decoded filenames contain only safe characters. |
| **MEDIUM** | `lib/services/title_id_registry_service.dart:194,223-228,231` | `isRetailConflict` and `!isInHomebrewRange` only produce warnings; `isValid` remains `true` for these IDs. | Users can create forwarders with `0100...` retail IDs or arbitrary 16-hex values, risking overwrite of installed retail games or unexpected Horizon behavior. | Make `isValid = false` unless the ID is inside `0x0500...0x05FF...` or the user explicitly overrides after a clear warning; tighten `registerTitleId` to refuse unsafe IDs. |
| **MEDIUM** | `lib/services/title_id_registry_service.dart:257-266` | `registerTitleId` writes the ID to `SharedPreferences` without re-running `validateTitleId`. | A future caller or batch import can poison the registry with reserved/system/retail IDs, bypassing the conflict guard on the next validation if cache is used. | Call `validateTitleId(id).isSafe` before persisting; reject unsafe IDs. |
| **MEDIUM** | `lib/services/keys_service.dart:21-25` | Uses deprecated `AndroidOptions(encryptedSharedPreferences: true)` and explicit `resetOnError: true`. In `flutter_secure_storage` v10 the `encryptedSharedPreferences` parameter is ignored; `resetOnError` can wipe keys on Keystore corruption. | Silent data loss on key-rotation or corruption; reliance on deprecated options may break in v11. | Use the modern `AndroidOptions()` constructor or `AndroidOptions.biometric()` with `resetOnError: false` and an explicit migration strategy; avoid deprecated flags. |
| **MEDIUM** | `lib/models/prod_keys.dart:2-3,10-28,30-32,36-37` | `ProdKeys` stores the entire raw `prod.keys` blob in `rawText` and a `Map` of values. `isValid` does not include `titlekdk_00` even though `HealthDiagnosticService` checks it. | Raw key material remains in memory; valid `titlekdk_00`-only key files are rejected; invalid/malformed values are accepted. | Drop `rawText` after parsing; validate expected key lengths/hex; include `titlekdk_00` in `isValid` or adjust the diagnostic check. |
| **LOW** | `android/app/build.gradle:30-34` | Release build uses `signingConfig signingConfigs.debug`, `minifyEnabled false`, `shrinkResources false`. | Reverse engineering and tampering are easier because the APK is signed with the well-known debug keystore and not minified. | Use a release signing config, enable R8/ProGuard, and `shrinkResources true` for release builds. |
| **LOW** | `lib/widgets/title_id_input.dart:34-41` | `generateRandomID` uses `dart:math` `Random()` (non-cryptographic) and does not check for collisions. | Statistically unlikely but possible ID collisions; not suitable for any security-critical use. | Switch to `Random.secure()` and validate against `TitleIdRegistryService` before returning. |
| **LOW** | `pubspec.yaml:12-24` + `pubspec.lock` | Direct dependencies include `iconic_morph` (small, low-traction package) and `google_fonts` (remote font fetcher). Versions are pinned in `pubspec.lock`, but `pubspec.yaml` uses `^` ranges and no dependency-audit tooling is integrated. | Supply-chain and transitive-vulnerability risk if lock file is regenerated or a dependency is compromised. | Pin exact versions or constrain narrowly in `pubspec.yaml`; run `flutter pub audit`/OSV scanning in CI; vendor or pin `iconic_morph` if it is not actively maintained. |
| **LOW** | Test suite (see §4) | Security invariants for network path traversal, file-saver filename sanitization, and key-memory wiping are not tested. | Regressions in critical security controls could go undetected. | Add tests for `..` traversal in `FileSaverService`, malicious `/nsp/../` requests, oversized range requests, and that `_testFallback` is cleared on `clearKeys()`. |

---

## 4. Supporting Evidence & Code Snippets

### 4.1 Network server binds to `0.0.0.0` with wildcard CORS

```dart
// lib/services/network_install_service.dart:180-199
_server = await HttpServer.bind(InternetAddress.anyIPv4, port);
_server!.idleTimeout = null;

// lib/services/network_install_service.dart:244-249
request.response.headers.set('Access-Control-Allow-Origin', '*');
request.response.headers
    .set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
request.response.headers.set('Access-Control-Allow-Headers', '*');
```

Binding to `anyIPv4` and adding `Access-Control-Allow-Origin: *` makes the local NSP server reachable from any website a user visits while on the same network.

### 4.2 File-saver path traversal via unsanitized filename

```dart
// lib/services/file_saver_service.dart:142-153
static Future<String?> _tryWriteFile(
  Directory dir,
  String filename,
  Uint8List bytes,
) async {
  // ...
  final filePath = p.join(dir.path, filename);   // <-- no basename/sanitization
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);
  // ...
}
```

`p.join` can be redirected by an absolute or `../` filename, especially on Windows drive-letter paths.

### 4.3 Over-privileged Android manifest

```xml
<!-- android/app/src/main/AndroidManifest.xml:4-7 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- android/app/src/main/AndroidManifest.xml:9-14 -->
<application
    android:label="NSPFF (NSP Fast Forward)"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:requestLegacyExternalStorage="true"
    android:enableOnBackInvokedCallback="true">
```

`MANAGE_EXTERNAL_STORAGE` is declared but the runtime grant flow is missing. `android:allowBackup` is **not** set to `false`, so the default `true` applies.

### 4.4 Plaintext in-memory `_testFallback` cache

```dart
// lib/services/keys_service.dart:31-34
static final Map<String, String> _testFallback = <String, String>{};
static bool _forceFallback = false;

// lib/services/keys_service.dart:67-84
static Future<void> _writeSecure(String key, String value) async {
  if (_forceFallback) {
    _testFallback[key] = value;
    return;
  }
  try {
    await _storage.write(
      key: key,
      value: value,
      aOptions: _androidOptions,
    );
    _testFallback[key] = value;          // <-- caches raw prod.keys
  } on MissingPluginException {
    _testFallback[key] = value;
  } on PlatformException {
    _testFallback[key] = value;
  }
}

// lib/services/keys_service.dart:87-106
static Future<String?> _readSecure(String key) async {
  if (_forceFallback) {
    return _testFallback[key];
  }
  try {
    final value = await _storage.read(/* ... */);
    if (value != null) {
      _testFallback[key] = value;        // <-- caches on every read
      return value;
    }
    return _testFallback[key];
  } on MissingPluginException {
    return _testFallback[key];
  } on PlatformException {
    return _testFallback[key];
  }
}
```

Even when `_forceFallback` is `false`, the fallback map is populated and may become the source of truth after a Keystore exception.

### 4.5 Title ID validation treats retail and out-of-range as warnings only

```dart
// lib/services/title_id_registry_service.dart:194
final bool isRetailConflict = clean.startsWith('0100') && !isReservedSystem;

// lib/services/title_id_registry_service.dart:223-228
} else if (isRetailConflict) {
  warning =
      'Warning: 0100... Title IDs are reserved for official retail games...';
} else if (!isInHomebrewRange) {
  warning =
      'Warning: Title ID $clean falls outside the recommended homebrew forwarder range...';
}

// lib/services/title_id_registry_service.dart:231
final bool isValid = !isReservedSystem;
```

`isValid` is `true` for both retail and non-homebrew IDs, making the guard non-blocking.

### 4.6 Deprecated / risky `AndroidOptions` usage

```dart
// lib/services/keys_service.dart:21-25
// ignore: deprecated_member_use
static const AndroidOptions _androidOptions = AndroidOptions(
  // ignore: deprecated_member_use
  encryptedSharedPreferences: true,
  resetOnError: true,
);
```

`encryptedSharedPreferences` is deprecated and ignored in `flutter_secure_storage` v10. `resetOnError: true` may destroy keys on Keystore errors.

### 4.7 `ProdKeys` keeps raw blob and has mismatched validity rule

```dart
// lib/models/prod_keys.dart:1-3
class ProdKeys {
  final String rawText;
  final Map<String, String> keysMap;

// lib/models/prod_keys.dart:30-32
bool get isValid =>
    keysMap.isNotEmpty &&
    (hasHeaderKey || hasSdSeed || hasKeyAreaKey || hasTitleKek);

// lib/models/prod_keys.dart:36-37
bool get hasTitleKdk => keysMap.containsKey('titlekdk_00');
bool get hasTitleKek => keysMap.containsKey('titlekek_00');
```

`isValid` does not require `titlekdk_00`, yet `HealthDiagnosticService` reports it as a required key.

### 4.8 Release build configuration

```gradle
// android/app/build.gradle:29-35
buildTypes {
    release {
        signingConfig signingConfigs.debug
        minifyEnabled false
        shrinkResources false
    }
}
```

A production build is signed with the debug keystore and is not minified.

---

## 5. Test Coverage Assessment

### Tests run during this audit

| Test file | Result | Notes |
|-----------|--------|-------|
| `test/services/title_id_registry_service_test.dart` | **Pass** (27/27) | Good boundary coverage for system-module/data/applet ranges and homebrew range. |
| `test/services/keys_service_secure_test.dart` | **Pass** (10/10) | Verifies migration, eviction, and encrypted options. |
| `test/security/security_test.dart` | **Pass** (3/3) | Tests `SwitchTextField.normalizePath`, random ID generation, and generated filename regex. |

### Coverage gaps

- **Network path traversal:** `network_install_service_test.dart` checks 404 for unregistered files but does not test `..`, encoded separators, or `filename` injection.
- **DoS / resource limits:** No tests for oversized `Range` headers, huge registered NSPs, or many concurrent connections.
- **File-saver filename sanitization:** `file_saver_service_test.dart` uses safe names; no `../` or absolute-filename test.
- **Key-memory wiping:** No test asserts that `_testFallback` is empty in production mode or that `rawText` is not retained after parsing.
- **CORS / origin binding:** No tests verify the server rejects cross-origin or binds to the intended interface.
- **Title ID registry poisoning:** No test checks that `registerTitleId` refuses a reserved or retail ID.

---

## 6. Dependency Security Review

| Package | Pinned version | Risk assessment |
|---------|----------------|-----------------|
| `flutter_secure_storage` | `10.3.1` | Up-to-date; migrated to custom ciphers. The app uses deprecated options but they are ignored, so the actual crypto is `AES-GCM` + `RSA-OAEP`. |
| `crypto` | `3.0.7` | Standard Dart crypto primitives; no known issues. |
| `image` | `4.9.2` | Current; used for JPEG icon encoding. Ensure inputs are validated to avoid malformed image DoS. |
| `file_picker` | `8.3.7` | Current; used for SAF folder selection. |
| `path_provider` / `shared_preferences` | `2.1.6` / `2.5.5` | Current. `SharedPreferences` is **not** encrypted; used for history and registry. |
| `http` | `1.6.0` | Current; only used in tests / client fetches. Ensure HTTPS is enforced for any remote fetch. |
| `google_fonts` | `8.2.1` | Downloads fonts at runtime over HTTPS; minor privacy/leakage of font usage. |
| `iconic_morph` | `1.9.0` | Small package with low community traction; pin exact version and review upstream for supply-chain risk. |
| `qr_flutter` | `4.1.0` | Current. |

**Recommendation:** Add a CI step that runs `flutter pub audit` or an OSV-based scanner, and convert `pubspec.yaml` direct dependencies to exact pinned versions for reproducibility.

---

## 7. Prioritized Action Roadmap

### Immediate (P0 — before any public release)

1. **Lock down the network installer.**
   - Bind to the specific LAN IP returned by `detectLocalIp()` by default; offer an optional loopback-only mode.
   - Remove `Access-Control-Allow-Origin: *`. Return a minimal CORS policy or no CORS headers.
   - Add a per-session random token in the install URL (e.g. `/nsp/<token>/<filename>`) and validate it in `_serveNsp`.
2. **Prevent file-system path traversal.**
   - In `FileSaverService._tryWriteFile`, apply `p.basename` and a strict filename whitelist before joining.
   - Never allow an absolute or `..`-containing filename.
3. **Reduce Android permission surface.**
   - Remove `MANAGE_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `READ_EXTERNAL_STORAGE`, and `requestLegacyExternalStorage` if not strictly required.
   - Use `MediaStore` / `ACTION_OPEN_DOCUMENT_TREE` for user-visible downloads.
   - Set `android:allowBackup="false"` or provide `fullBackupContent` exclusion rules.

### Short-term (P1 — within next sprint)

4. **Fix key-material handling.**
   - Remove `_testFallback` from the production code path or restrict it to test builds.
   - Avoid caching the raw `prod.keys` string; parse once and clear `rawText`.
   - Upgrade `KeysService` to modern `AndroidOptions()` or `AndroidOptions.biometric()` and drop the deprecated parameters.
5. **Harden the HTTP server.**
   - Set `idleTimeout` to a reasonable duration (e.g. 30s), cap the number of concurrent connections, and add rate limiting.
   - Validate the decoded `filename` against a safe-character regex.
   - Add Host-header checks to mitigate DNS rebinding.
6. **Strengthen Title ID guard.**
   - Make `isValid` `false` for retail (`0100...`) and out-of-homebrew-range IDs unless the user explicitly overrides.
   - Reject unsafe IDs in `registerTitleId`.
7. **Fix `ProdKeys` parser.**
   - Include `titlekdk_00` in `isValid` or align diagnostic requirements.
   - Validate expected key lengths and drop `rawText` after parsing.

### Medium-term (P2 — hardening)

8. **Enable release build protections.**
   - Use a release signing config; enable `minifyEnabled true` and `shrinkResources true`.
9. **Encrypt non-key `SharedPreferences` data.**
   - Use `encrypted_shared_preferences` or similar for `preset_service` history and `title_id_registry_service` registry.
10. **Expand security test coverage.**
    - Add traversal, DoS, CORS, and key-wiping tests.
    - Add a test that `registerTitleId` refuses reserved/retail/out-of-range IDs.
11. **Dependency supply-chain hygiene.**
    - Pin exact versions in `pubspec.yaml`, integrate `flutter pub audit` / OSV in CI, and review `iconic_morph` maintenance status.

---

**Report generated by:** Ciel General Council — Safety & Security Council  
**Output file:** `/Users/mey/NSPFF/ciel_audit_safety.md`
