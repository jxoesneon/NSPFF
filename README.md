# NSPFF (NSP Fast Forward)

[![CI Status](https://github.com/jxoesneon/NSPFF/actions/workflows/ci.yml/badge.svg)](https://github.com/jxoesneon/NSPFF/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-333333.svg)]()
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2.svg)](https://dart.dev)

**NSPFF** (NSP Fast Forward) is a Flutter application for constructing Nintendo Switch Package (`.nsp`) forwarders. The application generates valid home-screen shortcuts for standalone `.nro` executables and RetroArch emulator cores, running natively on Android, macOS, Windows, Linux, and the web.

The implementation is derived from the specification established by [TooTallNate/switch-tools](https://github.com/TooTallNate/switch-tools), providing full parity while expanding capability with client-side binary construction, key validation, and automated multi-ROM batch packaging.

---

## Technical Specifications & Binary Architecture

NSPFF constructs compliant Nintendo Switch installation packages by assembling Partition File System 0 (PFS0) containers containing Control, Program, and Metadata NCAs.

```
+-----------------------------------------------------------------------+
|                         PFS0 NSP Container                            |
+-------------------+--------------------+------------------------------+
| Control NCA       | Program NCA (ExeFS)| CNMT Meta NCA                |
| - icon.dat        | - main.npdm        | - Application Metadata       |
| - control.nacp    | - Target Path Stub | - Content Records            |
+-------------------+--------------------+------------------------------+
```

### 1. Control NACP Layout
The Nintendo Application Control Property structure is initialized as a `0x4000` byte buffer adhering to Nintendo Horizon system specifications:
* **Language Entries (`0x0000` - `0x2FFF`):** 16 language blocks, each `0x300` bytes (Title string max `0x1FE` bytes, Publisher max `0xFE` bytes).
* **Title ID (`0x3038`):** 64-bit unsigned integer serialized in Little-Endian byte order.
* **Version String (`0x3060`):** 16-byte UTF-8 string buffer.
* **System Flags:**
  * Startup User Account (`0x3025`)
  * Screenshot Capture (`0x3034`)
  * Video Capture (`0x3035`)
  * SVC Debug Permission (`0x3036`)
  * Logo Type (`0x30F0`)

### 2. NRO Asset Parser
Reads binary executables to extract embedded assets:
* Verifies `NRO0` magic signature at offset `0x10`.
* Locates the `ASET` section header at the executable boundary (`nroSize`).
* Extracts NACP control metadata and 256x256 icon payloads without native process dependencies.

---

## Feature Comparison

| Feature Capability | Web Baseline (`nsp-forwarder`) | NSPFF Engine | Status |
|---|---|---|---|
| Standalone NRO Forwarding | Supported | Supported | Full Parity |
| RetroArch Core Forwarding | Supported | Supported (35+ Built-in Cores) | Full Parity |
| Advanced Launch Flags | Supported | Supported | Full Parity |
| Binary NACP Auto-Extraction | Supported | Supported | Full Parity |
| 256x256 Icon Processing | Supported | Supported (Switch Icon Preview Frame) | Full Parity |
| Persistent Key Diagnostics | Session-based | Persistent Storage & Health Checks | Expanded |
| Multi-ROM Batch Packaging | Not Supported | Supported (Sequential Title ID Assignment) | Expanded |
| Architecture | Web / WASM | Pure Dart Native (Client-Side, Multi-Platform) | Expanded |

---

## Repository Structure

```
NSPFF/
├── .github/
│   └── workflows/          # GitHub Actions CI/CD automation
├── android/                # Android platform configuration
├── integration_test/       # End-to-end integration tests
├── lib/
│   ├── main.dart           # Application entry point
│   ├── models/             # Data structures (ForwarderConfig, ProdKeys, RetroArchCore)
│   ├── services/           # Binary packaging engines (NacpBuilder, NspGenerator, NroParser)
│   ├── theme/              # Horizon OS design tokens & typography
│   ├── views/              # Primary application screens
│   └── widgets/            # Reusable UI components
├── linux/                  # Linux platform configuration
├── macos/                  # macOS platform configuration
├── test/                   # Unit test suite
├── web/                    # Web platform configuration
├── windows/                # Windows platform configuration
├── ARCHITECTURE.md         # System architecture specification
├── CHANGELOG.md            # Version history
├── CODE_OF_CONDUCT.md      # Community standards
├── CONTRIBUTING.md         # Contribution guidelines
├── DEPENDENCIES.md         # Software bill of materials
├── LICENSE                 # MIT License
├── README.md               # Project overview
├── SECURITY.md             # Vulnerability reporting policy
├── THREAT_MODEL.md         # STRIDE threat model
└── pubspec.yaml            # Dependencies and asset declarations
```

---

## Build Instructions

### Prerequisites
* Flutter SDK `>= 3.0.0`
* Android SDK (`minSdkVersion: 21`, `targetSdkVersion: 34`) — for Android builds
* Java JDK 17 — for Android builds
* CMake + Ninja — for Linux and Windows desktop builds
* Xcode — for macOS builds

### Compilation
1. Resolve dependencies:
   ```bash
   flutter pub get
   ```

2. Execute static analysis and unit tests:
   ```bash
   flutter analyze
   flutter test
   ```

3. Build for a target platform:
   ```bash
   flutter build apk --release        # Android APK
   flutter build appbundle --release  # Android App Bundle (AAB)
   flutter build web --release        # Web
   flutter build macos --release      # macOS
   flutter build windows --release    # Windows
   flutter build linux --release      # Linux
   ```

---

## System Safety & Regulatory Notice

Installing custom NSP forwarders alters system ticket registries on target consoles. Operates exclusively on custom firmware environments (Atmosphere) with appropriate sigpatches. Use dedicated offline emuMMC configurations with DNS MITM or Exosphere enabled to prevent unauthorized telemetry submission to console services.

---

## License

Distributed under the [MIT License](LICENSE).
