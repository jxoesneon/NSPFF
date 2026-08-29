# NSPFF (NSP Fast Forward)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Flutter-brightgreen.svg)]()
[![Parity](https://img.shields.io/badge/Parity-1%3A1%2B%20Exceeds-cyan.svg)]()

**NSPFF (NSP Fast Forward)** is a high-performance Android application built with Flutter to generate Nintendo Switch NSP forwarders for standalone `.nro` homebrew applications and RetroArch ROM shortcuts.

It is based on [TooTallNate/switch-tools (nsp-forwarder)](https://github.com/TooTallNate/switch-tools/tree/main/apps/nsp-forwarder), delivering **1:1 parity and exceeding the original project in all core areas**.

---

## 🌟 Key Features & Parity Matrix

| Feature | Original Web App (`nsp-forwarder`) | NSPFF (NSP Fast Forward) | Parity Level |
|---|---|---|---|
| **NRO Forwarder Mode** | ✅ Title, Author, NRO Path, ID, Version | ✅ Title, Author, NRO Path, ID, Version | 1:1 Parity |
| **RetroArch Mode** | ✅ Core Selector, Core Path, ROM Path | ✅ Core Selector (35+ Cores), Core Path, ROM Path | 1:1 Parity |
| **Advanced Options** | ✅ Startup User Account, Screenshots, Video Capture, SVC Debug, Logo Type | ✅ Startup User Account, Screenshots, Video Capture, SVC Debug, Logo Type | 1:1 Parity |
| **Auto NACP Extractor** | ✅ Extract metadata from `.nro` | ✅ Extract NACP metadata & icons directly from `.nro` | 1:1 Parity |
| **Custom Boxart & Icons** | ✅ 256x256 Image Upload & Crop | ✅ Live Switch Icon Frame Preview & Auto 256x256 JPEG Encoder | 1:1+ Exceeds |
| **Title ID Generator** | ✅ Randomizer | ✅ Non-colliding Randomizer & Manual Override | 1:1+ Exceeds |
| **`prod.keys` Manager** | ⚠️ Upload per build | ✅ Persistent Storage & Live Key Diagnostic Status Cards | 1:1+ Exceeds |
| **Batch ROM Generator** | ❌ Not supported | ✅ Sequential Multi-ROM NSP Batch Generator | 1:1+ Exceeds |
| **Saved Profile History** | ❌ Not supported | ✅ History log with profile re-export | 1:1+ Exceeds |
| **Offline Privacy** | ❌ Server/Web dependent | ✅ 100% Client-side native generation on device | 1:1+ Exceeds |

---

## 📱 App Screenshots & Switch Horizon UI

The application features a sleek dark UI inspired by the **Nintendo Switch Horizon OS**:
- **Switch Cyan (`#00C4EF`)** and **Joy-Con Red (`#FF3655`)** glowing accents.
- Modern glassmorphic cards and rounded icon frame previews.
- Instant diagnostics bar for `prod.keys` validation.

---

## 🛠️ Project Structure

```
NSPFF/
├── android/                   # Android native wrapper & permissions
├── lib/
│   ├── main.dart              # Application entry point
│   ├── theme/
│   │   └── switch_theme.dart  # Nintendo Switch Horizon design system
│   ├── models/
│   │   ├── forwarder_config.dart # NRO & RetroArch options model
│   │   ├── retroarch_core.dart  # 35+ preconfigured RetroArch cores
│   │   └── prod_keys.dart       # Cryptographic keys container & validator
│   ├── services/
│   │   ├── nacp_builder.dart  # NACP (0x4000 byte) control structure builder
│   │   ├── nro_parser.dart    # NRO binary metadata & asset extractor
│   │   ├── nsp_generator.dart # PFS0 container, NCAs, & NSP builder
│   │   ├── keys_service.dart  # SharedPreferences key persistence
│   │   └── preset_service.dart# Preset history manager
│   ├── views/
│   │   ├── main_navigation_screen.dart # Switch Horizon tab navigation
│   │   ├── nro_forwarder_screen.dart   # NRO forwarder creator
│   │   ├── retroarch_forwarder_screen.dart # RetroArch forwarder creator
│   │   ├── batch_generator_screen.dart # Multi-ROM batch generator
│   │   ├── keys_manager_screen.dart    # Key manager & status diagnostics
│   │   ├── preset_history_screen.dart  # History & saved presets
│   │   └── guide_screen.dart           # Atmosphere & sigpatch guide
│   └── widgets/               # Switch UI controls, inputs, & previews
├── test/                      # Unit test suite
├── pubspec.yaml               # Flutter package manifest
└── README.md
```

---

## 🚀 Building & Running

### Requirements
- Flutter SDK `>=3.0.0`
- Android SDK 21+

### Build Android APK
```bash
flutter pub get
flutter build apk --release
```

The compiled APK will be located in `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🛡️ Console Ban Safety Notice
Installing custom NSP forwarders modifies system ticket databases on the Nintendo Switch console. Always ensure you are operating on an **offline emuMMC** with **DNS MITM** or **Exosphere** enabled to prevent bans from Nintendo online services.

---

## 📄 License
This project is open-source under the [MIT License](LICENSE).
