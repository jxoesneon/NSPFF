# Architecture Specification: NSPFF

## Executive Overview
**NSPFF (NSP Fast Forward)** is a native Android application engineered in Dart/Flutter designed to produce Nintendo Switch Package (`.nsp`) containers.

The application operates 1:1 on-device, performing binary payload generation, Partition File System 0 (PFS0) layout calculation, Nintendo Application Control Property (`NACP`) binary encoding, and `NRO0`/`ASET` binary asset parsing without external process calls or WebAssembly dependencies.

---

## 1. System Architecture (C4 Model)

```mermaid
graph TD
    subgraph Client Application Layer
        UI["Flutter Presentation Layer (Horizon OS Theme)"]
        State["State & Preset Management (SharedPreferences)"]
    end

    subgraph Service Layer (Pure Dart)
        NroParser["NRO Asset Parser (NRO0 / ASET)"]
        NacpBuilder["NACP Encoder (0x4000 Byte Engine)"]
        NspGen["PFS0 Container Builder"]
        KeysService["Cryptographic Keys Provider"]
    end

    subgraph Binary Outputs
        ControlNCA["Control NCA (NACP + Icon RomFS)"]
        ProgramNCA["Program NCA (ExeFS Stub + NPDM)"]
        MetaNCA["CNMT Metadata NCA"]
        PFS0["Final .nsp Package"]
    end

    UI --> NroParser
    UI --> NacpBuilder
    UI --> NspGen
    State --> KeysService
    KeysService --> NspGen
    
    NacpBuilder --> ControlNCA
    NroParser --> ControlNCA
    NspGen --> ProgramNCA
    NspGen --> MetaNCA
    
    ControlNCA --> PFS0
    ProgramNCA --> PFS0
    MetaNCA --> PFS0
```

---

## 2. Binary Packaging Pipeline

```
+-----------------------------------------------------------------------------------+
|                            NSP Packaging Pipeline                                 |
+-----------------------------------------------------------------------------------+
| 1. Input Processing: ForwarderConfig (Title, NRO Path, ROM Path, Title ID, Icon) |
| 2. Icon Formatting:  256x256 90% Quality JPEG Encoder                             |
| 3. NACP Generation:  0x4000 byte binary payload (Titles, Flags, 64-bit Title ID)  |
| 4. RomFS Generation: Header (0x50 bytes), Table Offsets, Control Payload          |
| 5. NCA Stubs:        NCA3 Header (0x400) + Section Offsets                        |
| 6. CNMT Creation:    Title ID, Version 1.0.0, Application Record                  |
| 7. PFS0 Container:   0x10 Header, 0x18 Entry Table, 0x20 Aligned String Table, Payload |
+-----------------------------------------------------------------------------------+
```

---

## 3. Data Integrity & Memory Model

### 64-Bit Title ID Serialization
Title IDs on Nintendo Switch are 64-bit unsigned integers (e.g. `0x0500000000000001`). To prevent integer truncation or signed bit overflow across 32-bit and 64-bit compilation targets:
```dart
static void _writeHexTitleId(Uint8List buffer, int offset, String hexId) {
  final cleanHex = hexId.replaceAll('0x', '').replaceAll(' ', '').toUpperCase().padLeft(16, '0');
  try {
    final BigInt val = BigInt.parse(cleanHex, radix: 16);
    BigInt temp = val;
    for (int i = 0; i < 8; i++) {
      buffer[offset + i] = (temp & BigInt.from(0xFF)).toInt();
      temp = temp >> 8;
    }
  } catch (_) {
    buffer[offset] = 0x01;
    buffer[offset + 7] = 0x05;
  }
}
```

---

## 4. Security & Cryptographic Isolation

1. **Storage Sandboxing:** `prod.keys` data is stored exclusively in encrypted application storage via `SharedPreferences`.
2. **Zero Network Telemetry:** NSPFF executes 100% offline. No key metrics or generated container data leave the host device.
3. **Path Sanitization:** Target SD card paths are normalized to Unix format (`/switch/app.nro`), suppressing path traversal attempts.
