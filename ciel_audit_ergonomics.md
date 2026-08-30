# Ciel General Council Audit — Evolution & Ergonomics

**Project:** `NSPFF` Flutter Android NSP forwarder generator  
**Auditor:** Evolution & Ergonomics Council  
**Date:** 2026-01-18  
**Scope:** `lib/theme/`, `lib/widgets/`, `lib/views/`, `test/`, `integration_test/`

---

## 1. Executive Summary

| Category | Score | Rationale |
|----------|-------|-----------|
| Handheld / controller ergonomics | 60/100 | Strong Nintendo-style button mapping (A/B, L/R, +/-, X/Y) and a bottom HUD, but primary gamepad actions are **missing on the Batch tab**, root actions are incomplete, and the legend is not fully wired for touch. |
| Design-system fidelity (Horizon OS / Switch) | 70/100 | Consistent neon-glow dark theme, card shapes and Joy-Con palette, but reusable focus-glow widget is dead code, no responsive breakpoints, and some translucent badge colors drift below WCAG contrast. |
| Accessibility (a11y) | 50/100 | Good main-text contrast, but form labels are not bound to inputs, several touch targets are below 44×44 dp, conflict badges fail WCAG AA, and there is no text-scale clamping. |
| Widget architecture | 55/100 | Reusable widget library exists, but build methods are monolithic (some >600 lines), focus-node lifecycle is copy-pasted everywhere, and the intended reusable focus wrapper is unused. |
| Test coverage & quality | 65/100 | All 136 unit/widget tests pass, but line coverage is ~73.5%, view coverage is as low as 32%, the single integration test was not executed, and a11y/golden tests are minimal. |
| **Overall UX / Ergonomics / Accessibility** | **58/100** | **Moderate** — a polished visual core with credible gamepad support, but the experience is inconsistent across tabs, accessibility is incomplete, and several widgets need structural clean-up. |

**Test-coverage summary**

- `flutter test` (project root) — **136 tests passed, 0 failed** (`00:05 +136: All tests passed!`).
- `flutter analyze` — **No issues found**.
- Pre-existing `coverage/lcov.info`: **39 source files**, **line coverage 73.55%** (`LH 2731 / LF 3713`), **no branch coverage data**.
- Lowest coverage in the audited user-facing files:
  - `lib/theme/switch_icons.dart` — 0.0%
  - `lib/views/batch_generator_screen.dart` — 32.8%
  - `lib/views/retroarch_forwarder_screen.dart` — 33.7%
  - `lib/views/nro_forwarder_screen.dart` — 34.4%
  - `lib/theme/switch_gamepad_navigation.dart` — 58.8%
- `integration_test/app_test.dart` was **not executed** by `flutter test` and requires `flutter test integration_test` or `flutter drive`.

---

## 2. Findings

| Severity | Location | Defect | Impact | Remedy |
|----------|----------|--------|--------|--------|
| **CRITICAL** | `lib/views/batch_generator_screen.dart` (entire `build`, lines 343–571) | The Batch tab has **no `Actions`/`GamepadStartIntent`/`GamepadQuickActionIntent`/`GamepadBrowseIntent` bindings** and does not import `switch_gamepad_navigation`. Pressing `+` (Generate), `X` (Auto-Fill) or `Y` (Browse) on a controller does nothing. | Core “controller-first” promise is broken for one of the primary screens; users cannot generate or browse ROMs via gamepad/physical controller. | Wrap the screen body in an `Actions` widget the same way `NroForwarderScreen` does (see `nro_forwarder_screen.dart:246–251`):
```dart
Actions(
  actions: {
    GamepadStartIntent: GamepadStartAction(onStart: _runBatchGeneration),
    GamepadQuickActionIntent: GamepadQuickAction(onQuickAction: _autoFormatBatchList),
    GamepadBrowseIntent: GamepadBrowseAction(onBrowse: _pickMultiRoms),
  },
  child: SingleChildScrollView(...),
)
``` |
| **HIGH** | `lib/widgets/title_id_input.dart` conflict/registered badges (lines 335–440) | **WCAG AA contrast failures** on warning pills. `Colors.white` text on `AppTheme.switchRed` measures **3.55:1**; `AppTheme.switchRed` text on the translucent red background at 12–15% alpha measures **4.07–4.22:1**; `AppTheme.switchYellow` text on layered yellow translucent backgrounds measures **~4.44:1**. All are below the 4.5:1 threshold for normal text. | Low-vision users and small screens cannot read safety-critical conflict warnings; creates regulatory / WCAG non-compliance exposure. | Use **black text** (`Color(0xFF000000)`) on `switchRed`/`switchYellow` accent backgrounds, or place the warning text on a solid dark surface. Verify every new color pair with a contrast tool. |
| **HIGH** | `lib/views/batch_generator_screen.dart` (343–571), `retroarch_forwarder_screen.dart` (344–535), `nro_forwarder_screen.dart` (245–405), `title_id_input.dart` (137–327), `network_install_dialog.dart` (176–796) | Build methods are **monolithic** (the dialog `build()` spans 621 lines) and mix UI, state, services, and formatting. They violate single-responsibility, make `const` extraction hard, and produce unnecessary rebuilds. | Poor maintainability, hard to unit-test, easy to introduce focus and const bugs; the 32–34% view coverage reflects this testability debt. | Decompose into smaller `StatelessWidget` builder methods/widgets (e.g., `_buildServerCard`, `_buildAccordion`, `_buildValidationBadge`). Move service/format helpers into private `State` methods or a dedicated `ViewModel`. Extract `const` subtrees where possible. |
| **HIGH** | `lib/theme/switch_gamepad_navigation.dart` lines 257–434 | `SwitchFocusGlow` and `SwitchFocusDecoration` are defined but **never used**; every interactive widget (`switch_button`, `switch_card`, `switch_text_field`, `switch_toggle`, `switch_dropdown`, `title_id_input`) reimplements the same `FocusNode` listener + `AnimatedContainer` neon-glow boilerplate. | Design-system asset is dead code; duplicated focus logic is error-prone and inconsistent (e.g., not all widgets expose `onFocusChange`). | Refactor all focusable widgets to use the existing `SwitchFocusGlow` wrapper, or extract a shared `FocusRing` widget. Delete the unused class or wire it into the widget library and add tests. |
| **MEDIUM** | `lib/views/main_navigation_screen.dart` app-bar icon buttons (lines 218–235), `lib/widgets/switch_info_tooltip.dart` (lines 70–81), `lib/widgets/network_install_dialog.dart` copy icon (lines 860–870) | Several tappable areas fall below the **WCAG 44×44 dp** minimum and the **Material 48×48 dp** ideal. AppBar `IconButton`s are constrained to `36×36` with `padding: EdgeInsets.zero`; the info tooltip is a 16 dp icon inside 4 dp padding (`~24×24`); the copy icon in the URL snippet is a 14 dp icon with 4 dp padding. | Motor-impaired users and handheld controller users can miss targets; can fail accessibility audits. | Enforce `BoxConstraints(minWidth: 44, minHeight: 44)` (or 48) and wrap small icons in `Material`/`InkWell` with at least 12 dp hit slop, or use `IconButton` defaults. |
| **MEDIUM** | `lib/widgets/switch_text_field.dart` (lines 107–127), `lib/widgets/switch_dropdown.dart` (lines 65–76), `lib/widgets/title_id_input.dart` (lines 170–191) | Form **labels are not semantically bound** to their inputs. A separate `Text` widget is rendered above the field, but `TextField`/`DropdownButton` receive no `labelText`/`Semantics` label. The `TitleIdInput` randomize button and `SwitchInfoTooltip` have no `Semantics` label. | Screen-reader users may hear the input as unlabeled, especially the randomize icon and the 16-hex Title ID field. | Wrap each input group with `Semantics(label: widget.label, child: ...)`, set `InputDecoration(labelText: widget.label, floatingLabelBehavior: FloatingLabelBehavior.never)`, and add `Semantics(label: ...)` to the randomize `InkWell` and tooltip icon. |
| **MEDIUM** | App-wide: no `MediaQuery` text-scaling or responsive layout usage (`grep` found 0 matches in `lib/`) | Fixed font sizes and fixed-height containers (`toolbarHeight: 40`, `SwitchButtonLegend` height 44, `_MorphingKeyStatusPill` height 32) with no `textScaler` clamp, no `LayoutBuilder`/`OrientationBuilder`, and no `ConstrainedBox` max-width on the main forms. | Text can overflow or be clipped when the user enables large font sizes in Android accessibility settings; forms stretch to full width on tablets/foldables and are hard to use. | Wrap the app in `MediaQuery(textScaler: textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.6))`, add `ConstrainedBox(maxWidth: 720)` around the form `Column`s, and test on tablet/foldable emulators. |
| **MEDIUM** | `lib/widgets/switch_info_tooltip.dart` lines 23–31 | Tooltips are dismissed by a **hard 5-second timer** (`Timer(const Duration(seconds: 5), () => Tooltip.dismissAllToolTips())`) regardless of whether the user is still reading or the tooltip has focus. | Users with motor/cognitive disabilities, or slow readers, may not finish reading helper text before it disappears. | Implement a focus-aware tooltip that stays visible while the trigger is focused or hovered, and only closes on explicit tap-out/Back. Use `TooltipTriggerMode.longPress` as an additional affordance. |
| **LOW** | `lib/views/main_navigation_screen.dart` lines 286–306 | `SwitchButtonLegend` is instantiated without `onQuickAction`, `onBrowse`, or `onStart`, so the X/Y/+ badges render as non-tappable `Container`s when `onTap == null` even though shortcuts can still fire when a widget in the body has the right `Actions`. | Minor inconsistency: a touch+controller user tapping a badge on the bottom HUD receives no feedback. | Pass the currently visible tab’s action callbacks into `SwitchButtonLegend`, or suppress badges whose `onTap` is null. |
| **LOW** | `lib/widgets/switch_text_field.dart` lines 152–164; `lib/widgets/title_id_input.dart` lines 282–291 | `onChanged` handlers forcibly rewrite the `TextEditingController` and reset `TextSelection.collapsed(offset: normalized.length)` after every path-sanitization / hex-sanitization. | Cursor is moved to the end on each edit, which is frustrating for keyboard users and screen-reader text navigation. | Sanitize on `onSubmitted`/`focus lost` only, or preserve the caret offset relative to the change. |
| **LOW** | `lib/widgets/network_install_dialog.dart` lines 349–402, 860–870 | `QrImageView` has no `Semantics` label, and the inline copy icon in `_buildUrlSnippet` has no `Tooltip`/`Semantics`. | Screen readers cannot explain the QR code or the copy action. | Wrap `QrImageView` in `Semantics(label: 'QR code to download ${activeUrl}', image: true)`. Replace the `InkWell` + `Icon` with an `IconButton(tooltip: 'Copy URL', ...)` or wrap in `Tooltip`/`Semantics`. |
| **LOW** | `lib/widgets/switch_button.dart` lines 147–165, 188 | When `isSuccess == true` the button still executes `onPressed`; the success animation merely changes appearance for 2 seconds. | A user can accidentally trigger a second generation while the success state is visible. | Set `onPressed: null` (or `isLoading: true`) while `isSuccess` is active, and ensure the button remains disabled until the success state is cleared. |
| **LOW** | `lib/theme/switch_gamepad_navigation.dart` lines 462–619 | `SwitchGamepadScope` registers global handlers only for `GamepadConfirm`, `GamepadBack`, and `GamepadToggleHud`. `GamepadStart/Quick/Browse` fall through silently if a screen forgets an `Actions` widget. | Inconsistent controller experience and silent failures like the Batch tab gap. | Provide safe no-op or `SnackBar` fallbacks in `SwitchGamepadScope`, or add `assert`/`debugFillProperties` checks that every tab registers the intents it advertises. |

---

## 3. Evidence & Metrics

### 3.1 Contrast measurements (WCAG AA target ≥ 4.5:1)

| Foreground | Background | Computed ratio | Pass/Fail | Notes |
|------------|------------|----------------|-----------|-------|
| `AppTheme.textPrimary` `#F3F4F6` | `AppTheme.darkBackground` `#121216` | **16.98:1** | Pass | Main body text. |
| `AppTheme.textSecondary` `#9CA3AF` | `AppTheme.cardBackground` `#1B1D26` | **6.62:1** | Pass | Subtitles and hints. |
| `AppTheme.textMuted` `#94A3B8` | `AppTheme.inputBackground` `#161820` | **6.91:1** | Pass | Helper text. |
| `Colors.black` | `AppTheme.switchCyan` `#00C4EF` | **10.14:1** | Pass | Primary button text. |
| `Colors.white` | `AppTheme.switchRed` `#FF3655` | **3.55:1** | **Fail** | `title_id_input` conflict badges (lines 361–368, 415–422). |
| `AppTheme.switchRed` | translucent red (`alpha 0.15`) over `cardBackground` | **4.07:1** | **Fail** | Conflict detail text (lines 375, 430). |
| `AppTheme.switchYellow` | layered translucent yellow over `cardBackground` | **~4.44:1** | **Fail** | “RETAIL GAME CONFLICT” badge text (lines 471–478). |

### 3.2 Controller mapping

The button mapping in `lib/theme/switch_gamepad_navigation.dart:57–91` is comprehensive:

```dart
SingleActivator(LogicalKeyboardKey.gameButtonA): GamepadConfirmIntent(),
SingleActivator(LogicalKeyboardKey.gameButtonB): GamepadBackIntent(),
SingleActivator(LogicalKeyboardKey.gameButtonX): GamepadQuickActionIntent(),
SingleActivator(LogicalKeyboardKey.gameButtonY): GamepadBrowseIntent(),
SingleActivator(LogicalKeyboardKey.gameButtonLeft1): GamepadPrevTabIntent(),
SingleActivator(LogicalKeyboardKey.gameButtonRight1): GamepadNextTabIntent(),
SingleActivator(LogicalKeyboardKey.gameButtonStart): GamepadStartIntent(),
SingleActivator(LogicalKeyboardKey.gameButtonSelect): GamepadToggleHudIntent(),
```

However, **only** `NroForwarderScreen` and `RetroArchForwarderScreen` declare handlers for `GamepadStart/Quick/Browse`; `BatchGeneratorScreen` does not, and `MainNavigationScreen` does not pass them to the `SwitchButtonLegend`.

### 3.3 Focus glow pattern

Every audited widget repeats the same pattern, e.g. `lib/widgets/switch_text_field.dart:129–145`:

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 150),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: _isFocused ? AppTheme.switchCyan : Colors.transparent,
      width: 2,
    ),
    boxShadow: _isFocused
        ? [BoxShadow(color: AppTheme.switchCyan.withValues(alpha: 0.5), ...)]
        : null,
  ),
  child: TextField(...),
)
```

The intended reusable wrapper `SwitchFocusGlow` in `lib/theme/switch_gamepad_navigation.dart:301–434` is **never referenced** outside its own test/coverage file (confirmed by `grep -R SwitchFocusGlow lib/` — no matches). This is the primary architectural duplication.

### 3.4 Build-method size

| File | `build()` line span | Approx. lines |
|------|--------------------:|--------------:|
| `lib/widgets/network_install_dialog.dart` | 176–796 | 621 |
| `lib/views/batch_generator_screen.dart` | 343–571 | 229 |
| `lib/views/retroarch_forwarder_screen.dart` | 344–535 | 192 |
| `lib/views/nro_forwarder_screen.dart` | 245–405 | 161 |
| `lib/widgets/title_id_input.dart` | 137–327 | 191 |

---

## 4. Prioritized Action Roadmap

### Phase 1 — Critical / blocking (before any release)
1. **Add gamepad `Actions` to `BatchGeneratorScreen`** (`GamepadStart`, `GamepadQuick`, `GamepadBrowse`) so the controller flow matches `NroForwarderScreen` and `RetroArchForwarderScreen`.
2. **Fix WCAG contrast failures** in `TitleIdInput` and any other red/yellow translucent badges; prefer black text on accent colors or solid dark surfaces.
3. **Validate and enforce 44×44 dp minimum touch targets** for all icon-only buttons and inline icons; upgrade `SwitchInfoTooltip`, app-bar icons, and URL-copy icon.

### Phase 2 — High (next sprint)
4. **Decompose oversized build methods** in `network_install_dialog.dart`, the three forwarder views, and `title_id_input.dart` into smaller `StatelessWidget` builders and helper widgets; add tests for each new piece to raise view coverage above 70%.
5. **Replace duplicated focus logic** with the existing `SwitchFocusGlow` or a new shared `FocusRing` wrapper; delete or fully exercise `SwitchFocusGlow`.
6. **Bind form labels to inputs** with `Semantics` and `InputDecoration(labelText: ..., floatingLabelBehavior: FloatingLabelBehavior.never)` so screen readers announce every field.

### Phase 3 — Medium (polish / robustness)
7. **Implement app-wide text-scale clamping** and responsive `ConstrainedBox`/`LayoutBuilder` layouts for tablets/foldables.
8. **Make tooltips persistent while focused/hovered** and remove the hard 5-second auto-dismiss.
9. **Wire `SwitchButtonLegend` callbacks** (`onQuickAction`, `onBrowse`, `onStart`) and suppress badges where no action is available.
10. **Add `Semantics` labels** to `QrImageView` and the inline copy icon.

### Phase 4 — Test / coverage
11. **Run and maintain the integration test** (`integration_test/app_test.dart`) on every build; generate branch coverage; add missing widget/golden tests and explicit WCAG contrast assertions.
12. **Add golden / pixel-diff tests** using `matchesGoldenFile` (currently `test/goldens/golden_tests.dart` only does basic finders) and screen-reader traversal tests using `tester.getSemanticsData`.

---

## 5. Commands Run

```bash
cd /Users/mey/NSPFF
flutter test          # 136 tests passed, 0 failed
flutter analyze       # No issues found
```

Coverage numbers were taken from the pre-existing `coverage/lcov.info`:

```text
Lines: 2731/3713 (73.55%)
Files: 39
Branch data: not present
```

---

*Report generated by the Ciel General Council Evolution & Ergonomics Auditor. No source files were modified during this audit.*
