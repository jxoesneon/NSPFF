# Ciel General Council — Comprehensive Audit Report

**Project:** `NSPFF` — Nintendo Switch NSP Forwarder Generator  
**Project root:** `/Users/mey/NSPFF`  
**Date:** 2026-08-30  
**Council:** Ciel General Council of Five  

## Auditors & Source Reports

| Council Pillar | Auditor | Score | Detailed Report |
|---|---|---|---|
| **Coherence & Efficiency** | 3b769814-0611-401a-9f02-92ce8c0a07ff | **76 / 100 (B)** | `ciel_coherence_efficiency_audit.md` (antigravity-cli artifact) |
| **Capability** | 87a3baaf | **48 / 100** | `ciel_audit_capability.md` |
| **Safety & Security** | 75b833ed | **52 / 100** | `ciel_audit_safety.md` |
| **Evolution & Ergonomics** | a343d6c9 | **58 / 100** | `ciel_audit_ergonomics.md` |

**Overall Council Verdict:** **58.5 / 100** — *Moderate, with multiple P0 findings that block production trust.*

---

## 1. Executive Summary

NSPFF is a feature-complete Flutter Android app that can already generate PFS0/NSP packages, launch a local HTTP installer, and target handheld controller ergonomics. The Coherence & Efficiency pillar scored highest because the network and batch infrastructure is well-structured at a high level. However, **three independent P0 defects** span binary correctness, network exposure, and controller accessibility:

1. **Generated Switch binaries fail integrity and content-type checks** (Capability).
2. **The wireless install server is open to the entire LAN with wildcard CORS** (Safety).
3. **The Batch tab has no gamepad action bindings** (Ergonomics).

Additionally, the Coherence & Efficiency report identified a **150–500 MB heap leak** during batch generation and a **per-chunk `flush()` bug** that collapses wireless transfer throughput. These are not aesthetic issues; they directly affect whether the app works at scale and whether generated NSPs install correctly on real Switch hardware.

The test suite passes (136 tests) but the audits show it does not exercise the structural invariants that matter most. Several tests even assert the wrong values for CNMT record types and NACP offsets, codifying the bugs.

---

## 2. P0 — Critical, Blocking Issues (Do Not Release Without Addressing)

| # | Finding | Council | Why It Is P0 |
|---|---------|---------|--------------|
| P0.1 | **IVFC master hash is at the wrong offset** in `lib/services/nca_builder.dart:528-539`. The master hash is written at `FsHeader` `0xA8` (IVFC `0xA0`) instead of `FsHeader` `0xC8` (IVFC `0xC0`). The real `MasterHash` field stays zero. | Capability | RomFS integrity verification fails on every generated Program and Control NCA. hactool and Switch FS will reject the package. |
| P0.2 | **CNMT content record types are swapped** in `lib/services/nca_builder.dart:162-163,203-219`. Program NCA is marked type `0` (Meta) and Control NCA type `1` (Program). Correct values are `1` (Program) and `3` (Control). | Capability | The content catalog is structurally wrong. Title installers and the Switch content manager may mis-associate or reject the NCAs. |
| P0.3 | **LAN-wide unauthenticated NSP server with wildcard CORS** in `lib/services/network_install_service.dart:194,246-249`. Binds to `InternetAddress.anyIPv4` and sets `Access-Control-Allow-Origin: *`. | Safety | Any device on the same network can download NSPs; malicious websites can exfiltrate data cross-origin from the local IP. |
| P0.4 | **Unbounded in-memory NSP retention** in `lib/services/batch_processor_service.dart:326-327` → `lib/services/network_install_service.dart:81,117`. Every generated NSP is stored in a singleton `Map<String, Uint8List>`. | Coherence & Efficiency | 50-item batches can pin 150–500 MB in heap, triggering Android Low Memory Killer on 2–4 GB devices. |
| P0.5 | **Per-chunk `flush()` kills network throughput** in `lib/services/network_install_service.dart:580-587`. `await request.response.flush()` is called for every 64 KB chunk. | Coherence & Efficiency | Transfer speed drops from ~50 MB/s to ~6–12 MB/s, quadrupling install time. |
| P0.6 | **Batch tab is missing controller actions** in `lib/views/batch_generator_screen.dart`. No `GamepadStart/Quick/Browse` `Actions` widget; `+`, `X`, `Y` do nothing on a physical controller. | Evolution & Ergonomics | A primary screen is unusable with a controller, breaking the core controller-first value proposition. |

---

## 3. Consolidated Findings Matrix

### 3.1 Capability (Binary Spec Compliance) — 48/100

| Severity | Location | Defect | Impact | Remedy |
|---|---|---|---|---|
| CRITICAL | `nca_builder.dart:528-539` | IVFC `MasterHash` at wrong `FsHeader` offset. | RomFS integrity fails. | Write master hash at `FsHeader` `0xC8` (`IVFC` `0xC0`); add correct padding/signature salt. |
| CRITICAL | `nca_builder.dart:162-163,203-219` | CNMT record types: Program=`0`, Control=`1` (wrong). | Content catalog inverted. | Use `1` for Program, `3` for Control; fix tests. |
| HIGH | `nca_builder.dart:555-564` | PFS0 `masterHash` computed over padded hash table. | ExeFS/Meta integrity fails. | Hash raw `hashTableSize` bytes only; pad separately on disk. |
| HIGH | `nca_builder.dart:47,587` | PFS0 padding `0x4000`, block size `0x8000` uniform. | Deviates from hacPack. | Use `0x200` padding and per-section block sizes (`0x10000` ExeFS, `0x1000` Meta). |
| MEDIUM | `nacp_builder.dart:58-60` | `enableSvcDebug` written to NACP `0x3036` (`DataLossConfirmation`); NPDM never patched. | Toggle is a no-op; flips unrelated bit. | Patch NPDM/ACID capability or remove the NACP write. |
| MEDIUM | `nsp_generator.dart:54-62` | JPEG quality loop stops at `10`; icon may exceed `0x20000`. | Switch home menu may reject icon. | Loop to `quality = 1` or throw explicit error. |
| MEDIUM | `forwarder_stub_template.dart` | No integrity check on embedded base64 stub. | Corrupted template yields broken `main`/`main.npdm`. | Add SHA-256 digest check and decode validation. |
| LOW | `nsp_generator.dart` | PFS0 logic duplicated; `lib/services/pfs0_builder.dart` does not exist. | Maintenance/DRY violation. | Extract a single `Pfs0Builder` service. |
| LOW | `nsp_generator.dart` | `ProdKeys` accepted but never used; NCAs plaintext. | User expectation mismatch. | Either sign/encrypt or surface a clear diagnostic. |
| HIGH | `test/services/nca_builder_test.dart`, `test/nacp_builder_test.dart` | Tests assert wrong values for CNMT types and NACP `0x3036`. | False confidence; bugs codified. | Rewrite tests against reference tool output. |

### 3.2 Safety & Security — 52/100

| Severity | Location | Defect | Impact | Remedy |
|---|---|---|---|---|
| CRITICAL | `network_install_service.dart:194,246-249` | Server binds `0.0.0.0` + wildcard CORS. | LAN exposure and cross-origin exfiltration. | Bind to selected LAN IP or loopback; remove `*` CORS; add per-session token. |
| HIGH | `file_saver_service.dart:151` + `AndroidManifest.xml:6` | `p.join(dir.path, filename)` without sanitization; `MANAGE_EXTERNAL_STORAGE` declared. | Path traversal and arbitrary writes. | Use `p.basename` and whitelist; remove broad storage permission unless explicitly granted. |
| HIGH | `AndroidManifest.xml:4-7,13` + `file_saver_service.dart:94-95` | Over-privileged manifest; hardcoded `/sdcard/Download`. | API 30+ write failures; over-permissioned. | Reduce to SAF/MediaStore; drop legacy storage flags. |
| MEDIUM | `keys_service.dart:31-34,67-84,87-106` | Plaintext `_testFallback` cache populated in production. | Key material persists in memory. | Guard fallback behind `kDebugMode`; clear aggressively. |
| MEDIUM | `AndroidManifest.xml:9-14` + `preset_service.dart`, `title_id_registry_service.dart:259-263` | Auto backup not disabled; history/IDs in plaintext `SharedPreferences`. | Backup exfiltration. | Set `android:allowBackup="false"`; encrypt prefs. |
| MEDIUM | `network_install_service.dart:195,244-283,514-528` | No idle timeout, rate limit, or request-size cap. | DoS / resource exhaustion. | Add `idleTimeout`, range caps, and filename validation. |
| MEDIUM | `title_id_registry_service.dart:194,223-228,231` | Retail and out-of-range IDs only warn; `isValid` stays `true`. | Can overwrite retail games. | Make `isValid = false` unless in homebrew range or explicit override. |
| MEDIUM | `title_id_registry_service.dart:257-266` | `registerTitleId` does not re-validate. | Registry poisoning. | Call `validateTitleId` before persisting. |
| MEDIUM | `keys_service.dart:21-25` | Deprecated `encryptedSharedPreferences` + `resetOnError: true`. | Silent data loss; ignored options. | Use modern `AndroidOptions`; set `resetOnError: false`. |
| MEDIUM | `models/prod_keys.dart:2-3,10-28,30-32,36-37` | `rawText` retained; `isValid` ignores `titlekdk_00`. | Memory exposure; invalid keys pass. | Drop `rawText` after parse; align validity rules. |
| LOW | `android/app/build.gradle:30-34` | Release uses debug signing, no minify/shrink. | Easy reverse engineering. | Release signing config, R8, `shrinkResources true`. |
| LOW | `widgets/title_id_input.dart:34-41` | `Random()` (non-cryptographic) for IDs. | Collision risk. | Use `Random.secure()` + collision check. |
| LOW | `pubspec.yaml` + `pubspec.lock` | `^` ranges; no dependency-audit tooling. | Supply-chain risk. | Pin or narrow versions; add `flutter pub audit`/OSV in CI. |

### 3.3 Coherence & Efficiency — 76/100

| Severity | Location | Defect | Impact | Remedy |
|---|---|---|---|---|
| CRITICAL | `batch_processor_service.dart:326-327` + `network_install_service.dart:81,117` | Singleton map retains every generated NSP byte array. | 150–500 MB heap leak. | Switch to file-backed `NspSource` with `File.openRead`. |
| CRITICAL | `network_install_service.dart:580-587` | `await request.response.flush()` per 64 KB chunk. | Throughput drops 4–8×. | Remove per-chunk flush; use 256 KB chunks; single flush/close. |
| HIGH | `services/autodetect_inference_service.dart:6` | Domain service imports `widgets/title_id_input.dart`. | Clean Architecture violation. | Move `generateRandomID` to `models/title_id.dart` or a domain service. |
| HIGH | `models/forwarder_config.dart:14-51` | Mutable fields; no `copyWith`/equality; raw image bytes in config. | Heap bloat; unpredictable state. | Make immutable with `final`, `copyWith`, `==`/hashCode; store image bytes separately. |
| HIGH | `services/network_install_service.dart:68-101,593-600` | `ChangeNotifier` + broadcast stream; `notifyListeners()` every 64 KB. | UI jank / frame drops. | Throttle to 10 Hz; use one notification channel. |
| HIGH | `services/nsp_generator.dart:51-68` | 4K image decode in isolates creates 265 MB spikes. | OOM during batch. | Pre-scale/decode with `cacheWidth`/`cacheHeight` or stream processing. |
| MEDIUM | `services/batch_processor_service.dart:326-335` | `BatchProcessorService` calls `NetworkInstallService.instance.registerNsp` directly. | Tight coupling and side effects. | Inject an `NspRegistration` interface. |
| MEDIUM | `services/batch_processor_service.dart:258-303` | `Isolate.run()` cannot be interrupted. | Wasted CPU/battery on cancel. | Use persistent isolate pool with cooperative cancellation or smaller chunks. |
| MEDIUM | `services/network_install_service.dart:583` | `nspBytes.sublist(offset, chunkEnd)` every chunk. | 100 MB GC churn per 100 MB transfer. | Use `Uint8List.sublistView` (zero-copy). |
| MEDIUM | `services/network_install_service.dart:588-591` | Cumulative average speed; millisecond truncation. | Jump/erratic telemetry. | Use Exponential Moving Average (EMA). |
| LOW | `services/batch_processor_service.dart:17-22,273-280,361-371` | No `cancelled` status. | Failed count is inflated. | Add `BatchItemStatus.cancelled`. |

### 3.4 Evolution & Ergonomics — 58/100

| Severity | Location | Defect | Impact | Remedy |
|---|---|---|---|---|
| CRITICAL | `views/batch_generator_screen.dart:343-571` | No `Actions` widget; `+`, `X`, `Y` do nothing. | Controller-first promise broken on primary screen. | Add `Actions` for `GamepadStart/Quick/Browse` matching other screens. |
| HIGH | `widgets/title_id_input.dart:335-440` | WCAG AA contrast failures (3.55:1, 4.07–4.22:1, ~4.44:1). | Conflict warnings unreadable. | Use black text on red/yellow badges or solid surfaces. |
| HIGH | `widgets/network_install_dialog.dart:176-796` etc. | `build()` spans 621 lines; duplicated focus logic. | Unmaintainable; poor coverage. | Decompose into smaller widgets; use shared `SwitchFocusGlow`. |
| HIGH | `theme/switch_gamepad_navigation.dart:257-434` | `SwitchFocusGlow`/`SwitchFocusDecoration` defined but never used. | Dead code; duplication. | Wire into all interactive widgets or delete. |
| MEDIUM | `views/main_navigation_screen.dart:218-235`, `widgets/switch_info_tooltip.dart:70-81`, `widgets/network_install_dialog.dart:860-870` | Touch targets below 44×44 dp. | Accessibility / motor-impairment failure. | Enforce `minWidth/minHeight: 44` (or 48). |
| MEDIUM | `widgets/switch_text_field.dart:107-127`, `widgets/switch_dropdown.dart:65-76`, `widgets/title_id_input.dart:170-191` | Labels not semantically bound. | Screen-reader unlabeled inputs. | Use `Semantics` + `InputDecoration(labelText:)`. |
| MEDIUM | App-wide | No `MediaQuery`, `textScaler`, `LayoutBuilder`. | Overflow on large fonts / tablets. | Add text-scale clamp and responsive max-width containers. |
| MEDIUM | `widgets/switch_info_tooltip.dart:23-31` | Hard 5-second tooltip timer. | Users with disabilities may miss text. | Focus-aware dismiss; explicit close. |
| LOW | `views/main_navigation_screen.dart:286-306` | `SwitchButtonLegend` callbacks not wired. | Tapping badges does nothing. | Pass tab action callbacks. |
| LOW | `widgets/switch_text_field.dart:152-164`, `widgets/title_id_input.dart:282-291` | `onChanged` resets cursor to end. | Frustrating text navigation. | Sanitize on submit/focus lost or preserve caret. |
| LOW | `widgets/network_install_dialog.dart:349-402,860-870` | QR / copy icon no `Semantics`. | Screen-reader unclear. | Add `Semantics` and `Tooltip`. |
| LOW | `widgets/switch_button.dart:147-165,188` | Success button still tappable. | Accidental double trigger. | Disable `onPressed` during success state. |

---

## 4. Cross-Council Themes

1. **The test suite passes but does not protect the project.**  
   `flutter test` reports 136 passing tests, `flutter analyze` reports no issues. Yet the tests assert wrong binary invariants (CNMT types, NACP offset), do not exercise security boundaries (path traversal, CORS, DoS), and cover only ~73.5% of lines with no branch coverage.

2. **The wireless install path is the most dangerous surface.**  
   Coherence, Capability, and Safety councils all converged on `network_install_service.dart`: it leaks memory, flushes per chunk, binds to all interfaces, allows wildcard cross-origin access, and has no rate/connection limits. This is the project’s critical cross-cutting concern.

3. **Generated binaries are not trustworthy yet.**  
   Capability found three independent structural defects that affect integrity verification and content cataloging. Until these are fixed and verified against hactool, generated NSPs should be treated as experimental.

4. **Controller UX is incomplete.**  
   The theme file is comprehensive, but `BatchGeneratorScreen` does not participate in the `Actions` system. The reusable focus widget is dead code, and touch targets/contrast are below WCAG AA in places.

---

## 5. Unified Prioritized Roadmap

### Phase 0 — Stop the Bleed (before any further testing on real hardware)
1. Fix `nca_builder.dart` IVFC master hash offset.
2. Fix `nca_builder.dart` CNMT record types (`Program=1`, `Control=3`).
3. Fix `nca_builder.dart` PFS0 master hash to hash raw table size.
4. Change `NetworkInstallService` to bind to the detected LAN IP only, remove `*` CORS, and add a per-session token.
5. Switch `NetworkInstallService` from in-memory byte map to file-backed streaming (`File.openRead`).
6. Remove per-chunk `flush()` in `NetworkInstallService`; use 256 KB chunks and throttled 10 Hz progress events.
7. Add `Actions` widget to `BatchGeneratorScreen` for `GamepadStart/Quick/Browse`.
8. Fix WCAG AA contrast in `title_id_input.dart` conflict badges.

### Phase 1 — Security & Storage Hardening
9. Sanitize filenames in `FileSaverService._tryWriteFile` with `p.basename` + whitelist.
10. Reduce Android manifest permissions; drop `MANAGE_EXTERNAL_STORAGE` unless explicitly granted.
11. Disable Android auto backup (`android:allowBackup="false"`) or exclude `shared_prefs`.
12. Replace plaintext `_testFallback` cache with debug-only fallback and clear-on-evict.
13. Enforce `isValid = false` for retail and out-of-range Title IDs unless explicit user override.
14. Add idle timeout, request-size caps, and filename validation to the HTTP server.

### Phase 2 — Architecture & Performance
15. Break `AutodetectInferenceService` dependency on `title_id_input.dart` UI widget.
16. Make `ForwarderConfig` immutable with `final` fields, `copyWith`, and value equality.
17. Replace `nspBytes.sublist` with `Uint8List.sublistView` in network streaming.
18. Replace cumulative speed calculation with EMA bandwidth estimator.
19. Implement an `NspSource` abstraction (file-backed and memory-backed).
20. Add `BatchItemStatus.cancelled` to batch processor.
21. Pre-scale/decode box art to avoid 4K → 256×256 decode spikes in isolates.

### Phase 3 — UI/UX & Accessibility
22. Decompose monolithic `build()` methods (especially `network_install_dialog.dart` and the three forwarder views).
23. Wire or remove `SwitchFocusGlow`; eliminate duplicated focus-ring code.
24. Enforce 44×44 (or 48×48) touch targets across icon-only controls.
25. Bind all form labels with `Semantics` and `InputDecoration(labelText:)`.
26. Add `MediaQuery` text-scale clamp and responsive `ConstrainedBox` max-width.
27. Replace hard 5-second tooltip with focus/hover-aware dismiss.
28. Wire `SwitchButtonLegend` tab callbacks and disable `SwitchButton` during success state.

### Phase 4 — Test Suite Overhaul
29. Rewrite `nca_builder_test.dart` and `nacp_builder_test.dart` to assert correct reference values.
30. Add hactool/hacPack golden-output comparison tests for generated NSPs.
31. Add security tests: path traversal in `FileSaverService` and `NetworkInstallService`, CORS rejection, oversized range requests, key-memory clearing.
32. Add integration-test run to CI (`flutter test integration_test`).
33. Add branch coverage and golden/pixel-diff tests.
34. Add explicit WCAG contrast assertions in widget/golden tests.

---

## 6. Verification Commands Run

```bash
cd /Users/mey/NSPFF
flutter analyze            # No issues found
flutter test               # 136 tests passed, 0 failed
flutter test --coverage    # 73.55% line coverage (pre-existing lcov)
```

The passing test suite should **not** be interpreted as a clean bill of health. The council found multiple defects that existing tests do not catch.

---

## 7. Conclusion

NSPFF is close to a shippable feature set but is not yet safe for production. The most urgent work is in three files:

- `lib/services/nca_builder.dart` — fix binary invariants.
- `lib/services/network_install_service.dart` — fix memory, throughput, and exposure.
- `lib/views/batch_generator_screen.dart` — fix controller ergonomics.

The council recommends completing **Phase 0** before any further end-to-end testing on real Switch hardware or public networks, then **Phase 1** before any release, and **Phases 2–4** as the next two sprints.

---

*Report synthesized by the Ciel General Council from the four pillar audit reports.*
