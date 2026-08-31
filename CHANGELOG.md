# Changelog

All notable changes to the **NSPFF (NSP Fast Forward)** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2026-08-31

### Added
- **NRO Application Forwarder Engine:** Pure Dart binary container packager for standalone `.nro` Switch applications.
- **RetroArch Core & ROM Forwarder Engine:** Pre-configured support for 35+ emulator cores with custom SD card path mapping.
- **Auto NACP Extractor:** Automatic parsing of `NRO0` header assets and `ASET` blocks directly from binary files.
- **Sequential Batch ROM Generator:** Automated multi-ROM package creation with collision-free 64-bit Title ID generation.
- **Key Manager & Diagnostics:** `prod.keys` parser and diagnostic status dashboard.
- **Nintendo Switch Horizon OS Theme:** Dark theme implementation with custom UI controls.
- **Gamepad Navigation:** Full gamepad support with focus traversal and fallback handling.
- **Network Installation:** Wireless NSP installation via QR code and direct URL.
- **Multi-Platform Support:** Android, macOS, Windows, Linux, and web builds.
- **Unit Test Suite & Automated CI/CD:** GitHub Actions pipeline for automated compilation and release artifact generation.

### Changed
- Upgraded to `file_picker` 12.x with static API and `PlatformFile.readAsBytes()`.
- Upgraded to `flutter_secure_storage` 11.x.
- All GitHub Actions upgraded to latest major versions.
- SHA-256 checksums generated for all release artifacts.
- Release artifacts now use native package formats: DMG (macOS), MSIX + portable ZIP (Windows), AppImage + DEB (Linux).

### Security
- User-supplied cryptographic keys stored in `flutter_secure_storage`; never committed or bundled.
- Release signing configurable via environment variables only.

---

## [1.0.0] - 2026-08-29

### Added
- **NRO Application Forwarder Engine:** Pure Dart binary container packager for standalone `.nro` Switch applications.
- **RetroArch Core & ROM Forwarder Engine:** Pre-configured support for 35+ emulator cores with custom SD card path mapping.
- **Auto NACP Extractor:** Automatic parsing of `NRO0` header assets and `ASET` blocks directly from binary files.
- **Sequential Batch ROM Generator:** Automated multi-ROM package creation with collision-free 64-bit Title ID generation.
- **Key Manager & Diagnostics:** `prod.keys` parser and diagnostic status dashboard.
- **Nintendo Switch Horizon OS Theme:** Dark theme implementation with custom UI controls.
- **Unit Test Suite & Automated CI/CD:** GitHub Actions pipeline for automated compilation and release artifact generation.
