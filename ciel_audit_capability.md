# Ciel General Council — Capability Council Audit Report
## NSPFF Nintendo Switch NSP Forwarder Generator

**Auditor:** Capability Council Auditor  
**Project root:** `/Users/mey/NSPFF`  
**Date:** 2026-01-18  
**Scope:** Nintendo Switch binary generators and specification compliance of the generated NCA/NSP/RomFS/PFS0/CNMT artifacts.

---

## 1. Executive Summary

This audit focused on whether the Dart generators in `/Users/mey/NSPFF/lib/services` produce structurally valid, specification-compliant Nintendo Switch binaries that are safe to install on Switch CFW (DBI / Tinfoil / Awoo). The implementation shows a good high-level understanding of the Switch file formats and the generated layouts are *mostly* close to the reference tools (hacPack / hactool / libnx), but **three independent, correctness-critical defects** were found in the binary assembly code. Two of them break integrity verification outright and one mislabels the NCA content type metadata, which means generated NSPs are very likely to fail strict validation by the Switch OS or by title-manager integrity checks.

**Overall Capability / Spec-Compliance Score: 48 / 100**

The score reflects the presence of multiple Critical/High findings that are present in *every* generated NSP, the weak test suite (which in several places asserts the *wrong* value, codifying the bugs), and the absence of input validation for edge cases that directly affect generated binary contents.

---

## 2. Audit Files Read

Source code:
- `lib/services/nsp_generator.dart`
- `lib/services/nca_builder.dart`
- `lib/services/romfs_builder.dart`
- `lib/services/forwarder_stub_template.dart`
- `lib/services/nacp_builder.dart`

Tests:
- `test/services/nca_builder_test.dart`
- `test/services/romfs_builder_test.dart`
- `test/nsp_generator_test.dart`
- `test/nacp_builder_test.dart` (discovered during audit)

Also consulted:
- `lib/models/forwarder_config.dart`
- `lib/models/prod_keys.dart`
- Switchbrew NCA / NCA Format / CNMT / NACP / NCM services specifications
- hacPack `nca.c`, `romfs.c`, `ivfc.c`, `pfs0.c`, `cnmt.c`, `pfs0.h`, `ivfc.h`, `cnmt.h`, `nca.h`
- hactool `nca.c`, `pfs0.h`, `ivfc.h`
- libnx `romfs_dev.h` / `nacp.h`

---

## 3. Evaluation by Component

### 3.1 NCA3 Container (`nca_builder.dart`)

**What is correct:**
- Magic `NCA3` is emitted at header offset `0x200` (line 423-426).
- `DistributionType` = `0` (Download), `ContentType` = `0/1/2` for Program/Meta/Control.
- `ContentSize` is written as a 64-bit LE value at `0x208` and equals the final buffer size.
- `TitleId` is written at `0x210`.
- Section table entries are placed at `0x240` / `0x250` with media start/end offsets in 512-byte blocks, matching the `FsEntry` layout.
- FsHeaders are at `0x400` / `0x600` / `0x800` / `0xA00` and each `0x200` bytes.
- SHA-256 of each FsHeader is stored in `section_hashes` at `0x280` / `0x2A0`, matching the NCA3 layout.
- Sections are padded to the 512-byte media block size (`blockSize = 0x200`).

**What is wrong or non-compliant:**

#### 3.1.1 IVFC / HierarchicalIntegrityHash master hash is at the wrong byte offset

The NCA `FsHeader` layout is:

```
0x00 version (u16)
0x02 fs_type (u8)
0x03 hash_type (u8)
0x04 crypt_type (u8)
0x05 metadata_hash_type (u8)
0x06 reserved (u16)
0x08 HashData (0xF8 bytes)
```

For `HierarchicalIntegrityHash` (RomFS / IVFC), `HashData` is an `IntegrityMetaInfo` structure:

```
0x00  Magic "IVFC"
0x04  Version / id
0x08  MasterHashSize
0x0C  InfoLevelHash (0xB4 bytes)
0xC0  MasterHash (0x20 bytes)
0xE0  Reserved (0x18 bytes)
```

Because `HashData` starts at FsHeader offset `0x08`, the **MasterHash field is at absolute FsHeader offset `0x08 + 0xC0 = 0xC8`**. hactool's `ivfc.h` confirms this layout:

```c
uint32_t magic;
uint32_t id;
uint32_t master_hash_size;
uint32_t num_levels;
ivfc_level_hdr_t level_headers[IVFC_MAX_LEVEL];  // 6 * 0x18 = 0x90, ends at 0xA0
uint8_t  _0xA0[0x20];                            // 0xA0-0xC0
uint8_t  master_hash[0x20];                      // 0xC0-0xE0
```

The code in `nca_builder.dart` writes the level headers at `0x18` and then immediately writes the master hash at `0xA8`:

```dart
// lines 528-539
for (int i = 0; i < 6; i++) {
  final int off = 0x18 + i * 0x18;
  fsView.setUint64(off + 0x00, ivfc.logicalOffsets[i], Endian.little);
  fsView.setUint64(off + 0x08, ivfc.hashDataSizes[i], Endian.little);
  fsView.setUint32(off + 0x10, 0x0E, Endian.little); // 1 << 14 = 0x4000
  fsView.setUint32(off + 0x14, 0, Endian.little); // Reserved
}

// Master hash at 0xA8 (0x20 bytes)
for (int i = 0; i < 0x20; i++) {
  fsView.setUint8(0xA8 + i, ivfc.masterHash[i]);
}
```

This places the master hash at IVFC superblock offset `0xA0`, which is the `_0xA0[0x20]` reserved / SignatureSalt area, **not** the `MasterHash` field. The *actual* `MasterHash` field at `0xC0` (`FsHeader` `0xC8`) is left as zero. hactool will compare the zeroed master hash with the SHA-256 of the top IVFC level and report `VALIDITY_INVALID`. This breaks every RomFS section in every generated NCA (Control NCA always, Program NCA section 1).

**Severity:** Critical

#### 3.1.2 PFS0 / HierarchicalSha256Hash master hash is computed over the padded hash table, not the raw hash table

For PFS0 sections (ExeFS and Meta NCA), the superblock stores `hash_table_size` (the raw size of the hash table) and `pfs0_offset` (the offset at which the actual PFS0 begins). The reference implementation (hacPack `pfs0_calculate_master_hash`) computes the master hash over **exactly** `hash_table_size` bytes, which is the raw, unpadded hash table. The section layout on disk is `[padded hash table][PFS0]`; only the raw part is hashed into the master hash.

In `nca_builder.dart` lines 555-564:

```dart
// 2. Pad hash table to 0x4000 boundary
const int htPadBoundary = 0x4000;
final int htPad = (htPadBoundary - (rawHashTable.length % htPadBoundary)) % htPadBoundary;
final Uint8List paddedHashTable = Uint8List(rawHashTable.length + htPad);
paddedHashTable.setRange(0, rawHashTable.length, rawHashTable);

// Master hash = SHA-256 of padded hash table
final masterHash = Uint8List.fromList(sha256.convert(paddedHashTable).bytes);
```

The master hash is computed over `paddedHashTable` (padded to a 0x4000 boundary), while the superblock reports `hashTableSize = rawHashTable.length`. hactool / Switch integrity verification will hash only `hashTableSize` bytes and compare with `masterHash`; the values will not match.

This also uses a hash-table padding boundary of `0x4000` and a uniform PFS0 hash block size of `0x8000`. The reference hacPack tool uses `PFS0_PADDING_SIZE = 0x200`, `PFS0_EXEFS_HASH_BLOCK_SIZE = 0x10000`, and `PFS0_META_HASH_BLOCK_SIZE = 0x1000`. While `0x8000` is a valid power-of-two block size, the hash-table padding mismatch is another spec deviation.

**Severity:** High (integrity failure for ExeFS and Meta NCA)

#### 3.1.3 NCA3 `KeyGeneration` / `KeyGenerationOld` values are inconsistent

```dart
// nca_builder.dart lines 430-442
view.setUint8(0x206, 2); // KeyGenerationOld
...
view.setUint8(0x220, 1); // KeyGeneration
```

`KeyGeneration` at `0x220` is set to `0x01`. The Switchbrew table enumerates values starting at `0x03` (3.0.1) and treats `0xFF` as Invalid. hacPack's `nca_set_keygen` leaves `0x220` at `0x00` for the default key generation (`keygeneration == 1`). Because the NCAs are plaintext (`crypt_type = 1`), this may be ignored by some CFW, but it is a spec inconsistency.

**Severity:** Low

#### 3.1.4 FsHeader `fs_type` / `partition_type` variable naming is misleading and a dead parameter exists

`nca_builder.dart` defines:

```dart
static const int partitionTypeRomfs = 0;  // actually fs_type RomFS
static const int partitionTypePfs0 = 1;   // actually fs_type PFS0
static const int fsTypeRomfs = 3;         // unused, wrong value
static const int fsTypePfs0 = 2;          // unused, wrong value
```

The builder writes the value it calls `partitionType` to FsHeader offset `0x02`, which is the **FsType** field. The `fsType` parameter in `_buildSingleSectionNca` / `_buildTwoSectionNca` is accepted but never written. The generated values happen to be correct (`0` for RomFS, `1` for PFS0), but the naming is inverted and the constants `fsTypePfs0` / `fsTypeRomfs` are not the real FS-type values. This is a maintenance/refactoring hazard.

**Severity:** Low

---

### 3.2 CNMT / Content Meta (`nca_builder.dart`)

The CNMT header, extended header, and record layout are mostly correct:
- `PackagedContentMetaHeader` (0x20 bytes) fields are in the right places.
- `ApplicationMetaExtendedHeader` is 0x10 bytes with `PatchId = TitleId + 0x800`.
- Records are 0x38 bytes (`hash[0x20]`, `ncaId[0x10]`, `size[0x06]`, `type[1]`, `idOffset[1]`).
- End digest is SHA-256 over `0x00..0xA0`.

However, the **content record `type` values are wrong**.

Per Switchbrew / libnx `NcmContentType`:

| Value | Type |
|-------|------|
| 0     | Meta |
| 1     | Program |
| 2     | Data |
| 3     | Control |

hacPack's `cnmt_create_application` does exactly this:

```c
cnmt_ctx.content_records[...].type = 0x1; // Program
cnmt_ctx.content_records[...].type = 0x3; // Control
```

But `nca_builder.dart` defaults `programRecordType = 0` and `controlRecordType = 1` and writes them at the record type offsets:

```dart
// nca_builder.dart lines 162-163, 209-219
static const int programRecordType = 0;
static const int controlRecordType = 1;
...
view.setUint8(recOffset + 0x36, programRecordType); // Program NCA marked as Meta
...
view.setUint8(recOffset + 0x36, controlRecordType); // Control NCA marked as Program
```

This means the generated CNMT says the Program NCA is a **Meta** content and the Control NCA is a **Program** content. This is a fundamental content-type mismatch and will cause the Switch content manager and title installers to mis-associate the NCAs or reject the package entirely.

The test file (`test/services/nca_builder_test.dart` lines 205-212) explicitly asserts these wrong values, so the test suite **codifies the bug** rather than catching it.

**Severity:** Critical

---

### 3.3 RomFS (`romfs_builder.dart`)

**What is correct:**
- Header is 0x50 bytes with 10 little-endian u64 fields in the correct order (`headerSize`, `dirHashTableOff`, `dirHashTableSize`, `dirTableOff`, `dirTableSize`, `fileHashTableOff`, `fileHashTableSize`, `fileTableOff`, `fileTableSize`, `fileDataOff`).
- File data partition starts at `0x200` (`ROMFS_FILEPARTITION_OFS`).
- File data is aligned to `0x10`.
- Directory entry is `0x18 + name-align-4` and file entry is `0x20 + name-align-4`.
- Directory/file fields (`parent`, `sibling`, `childDir`, `childFile`, `nextHash`, `nameLen`) are in the correct places.
- Path hash algorithm matches hacPack/libnx:
  ```dart
  int hash = (parentOffset ^ 123456789) & 0xFFFFFFFF;
  for (...) {
    hash = (((hash >> 5) | (hash << 27)) ^ nameBytes[i]) & 0xFFFFFFFF;
  }
  ```
- Hash-table bucket count heuristic matches hacPack.
- Output layout is file data → dir hash table → dir table → file hash table → file table.

**What is weak / missing:**
- No input validation on file name length or path depth. A file name longer than `0xFFFF` bytes (theoretical) would not truncate, and a path with many nested directories could lead to large metadata. This is not a practical crash, but there are no guardrails.
- `_formatSdmcPath` does not escape or validate special characters (`"`, control characters, null bytes) before writing them into RomFS file data. A ROM path containing `"` will break the `nextArgv` quoting convention (`nroPath "romPath"`).
- The `nextArgv` string is assembled without length caps; if the NRO/ROM paths are very long, the `nextArgv` file can exceed the forwarder stub's internal buffer. The stub is a closed binary, so this is a latent safety concern.

**Severity:** Low–Medium (depends on stub's buffer handling; unverified)

---

### 3.4 Forwarder Stub (`forwarder_stub_template.dart`)

- The base64 payloads decode to a 53,149-byte `NSO0` main binary and a 1,016-byte `META` NPDM. Magic checks pass.
- `getPatchedNpdm` patches the Title ID at hardcoded offsets `0x290`, `0x298` (ACID title-id range) and `0x350` (ACI0 title id). The test suite verifies these offsets for one sample title ID.
- The `enableSvcDebug` toggle in `ForwarderConfig` is **not applied to the NPDM** and therefore does not enable or disable any SVC debug capability. Instead, `NacpBuilder` writes it to NACP offset `0x3036`, which is `DataLossConfirmation` (see 3.5). This is at best misleading and at worst a security/UI bug.
- There is no integrity check (hash/known-good digest) on the embedded base64 stub. If the template string is truncated or corrupted, the generator will still emit a broken `main`/`main.npdm`.
- The PFS0 builder for ExeFS aligns the string table to `0x20` and produces a valid `main` + `main.npdm` PFS0, but because it lives inside the Program NCA, it is affected by the PFS0 master-hash bug described in 3.1.2.

**Severity:** Medium (stub behavior and `enableSvcDebug` no-op)

---

### 3.5 NACP (`nacp_builder.dart`)

**What is correct:**
- Buffer size is exactly `0x4000`.
- Title/publisher are written to all 16 language entries (`0x300` per entry, title `0x200`, publisher `0x100`).
- `StartupUserAccount` at `0x3025`, `Screenshot` at `0x3034`, `VideoCapture` at `0x3035`.
- `DisplayVersion` at `0x3060` (0x10 bytes).
- `LogoType` at `0x30F0`, `LogoHandling` at `0x30F1`.
- Title ID is written as a little-endian 64-bit value at `0x3038`.

**What is wrong:**

```dart
// nacp_builder.dart lines 58-60
// Enable SVC Debug: 0x3036 (0 = Disabled, 1 = Enabled)
buffer[0x3036] = config.enableSvcDebug ? 0x01 : 0x00;
```

NACP offset `0x3036` is `DataLossConfirmation`, not an SVC debug flag. SVC debug is an NPDM/ACID capability. The toggle therefore:
1. Does not actually enable SVC debugging.
2. Mutates `DataLossConfirmation` based on a UI control whose name says nothing about data loss.

**Severity:** Medium

**What is weak:**
- Title and publisher are truncated by raw byte length (`0x1FE` / `0xFE`). If a multi-byte UTF-8 character is split, the resulting NACP will contain an invalid UTF-8 sequence, which the Switch UI may reject.
- Version string uses a 15-byte cap (0x3060-0x306E), leaving no guaranteed null terminator if the version string is exactly 16 bytes.

**Severity:** Low

---

### 3.6 NSP / Outer PFS0 (`nsp_generator.dart`)

- The outer `.nsp` container is a valid PFS0 with the standard magic and file entry layout.
- It packages three NCAs named `<32-hex>.nca` (Program), `<32-hex>.nca` (Control), and `<32-hex>.cnmt.nca` (Meta). Naming matches the hacPack convention (first 16 bytes of the NCA SHA-256 as lowercase hex).
- String table is aligned to `0x20`.

**Weaknesses:**
- The requested audit file `lib/services/pfs0_builder.dart` **does not exist in the repository**. PFS0 construction is duplicated inline in `nsp_generator.dart` (`_buildPfs0`) and `forwarder_stub_template.dart` (`_buildPfs0`). This violates DRY and makes it easy for the two implementations to diverge.
- `NspGenerator.generateNsp` accepts a `ProdKeys keys` argument but **does not use it**. The NCAs are produced in plaintext (`crypt_type = 1`), so no keys are required. However, this means the `ProdKeys.isValid` check is purely informational and an invalid/empty keyset still produces an NSP. This contradicts user expectations and the UI's key-validation flow.

**Severity:** Low

**Icon handling:**

```dart
// nsp_generator.dart lines 54-62
int quality = 90;
iconJpgBytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
while (iconJpgBytes.length >= 0x20000 && quality > 10) {
  quality -= 10;
  iconJpgBytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}
```

The loop stops at `quality == 10`. If a 256x256 source still yields a JPEG ≥ `0x20000` bytes at `quality = 10`, the generator exits the loop and uses an oversized icon. The Switch home menu rejects control icons larger than `0x20000`. The loop should continue to `quality = 1` or throw an explicit error.

**Severity:** Medium

---

### 3.7 Test Coverage

The unit tests do not verify the most important binary invariants:

- **No master-hash verification** for either IVFC or PFS0 sections.
- **No cross-check against hactool/hacPack reference outputs.**
- **No negative / edge-case tests** for large icons, long paths, special characters, invalid title IDs, missing assets, or malformed prod.keys.
- **No test of the actual PFS0 hash table** (does the hash verify the PFS0 bytes? not checked).
- **No test of the NPDM** beyond magic and title-id offsets.
- **No test of NACP `DataLossConfirmation` semantics.**
- **Tests codify bugs:**
  - `test/services/nca_builder_test.dart` lines 205-212 asserts CNMT record types `0` and `1` instead of the correct `1` and `3`.
  - `test/nacp_builder_test.dart` line 27 asserts `nacp[0x3036] == 1` as "enableSvcDebug", which is actually `DataLossConfirmation`.
- **Tests use trivial placeholder data** (e.g., `Uint8List(0x4000)` for `nacpBytes`, `Uint8List(512)` for icon) that would not exercise real-world constraints.

The tests are therefore **happy-path smoke tests**, not specification-conformance tests. They give a false sense of confidence.

**Severity:** High

---

## 4. Findings Table

| Severity | Location | Defect | Impact | Remedy |
|----------|----------|--------|--------|--------|
| **CRITICAL** | `lib/services/nca_builder.dart:528-539` | IVFC `MasterHash` is written at FsHeader offset `0xA8` instead of the required `0xC8` (IVFC superblock offset `0xA0` vs `0xC0`). | RomFS integrity verification fails; the real `MasterHash` field is zero. Every generated Program and Control NCA's RomFS section will be rejected by hactool and likely by Switch FS integrity checks. | Insert `0x20` of zero padding/signature salt between the level headers and the master hash; write `MasterHash` at `0xC8` (`FsHeader` offset) / `0xC0` (`IVFC` offset). |
| **CRITICAL** | `lib/services/nca_builder.dart:162-163, 203-219` | CNMT `ContentRecord` types default to `programRecordType=0` and `controlRecordType=1` (and are asserted in tests). | Program NCA is marked as `Meta` (0) and Control NCA as `Program` (1) in the CNMT. This is a spec-inverted content catalog and will confuse or fail NCM / title installers. | Use `1` for Program and `3` for Control; add named constants (`NcmContentType_Program`, `NcmContentType_Control`) and remove the misleading parameters; fix tests. |
| **HIGH** | `lib/services/nca_builder.dart:555-564` | PFS0 `MasterHash` is SHA-256 of the **padded** hash table (`0x4000`-aligned), while `hash_table_size` reports the raw hash-table size. | Master hash will not match the hash of the `hash_table_size` bytes that integrity checkers actually read. ExeFS and Meta NCA integrity verification fails. | Compute `masterHash` from `rawHashTable`; use the raw size in the superblock; optionally align the on-disk padding to `0x200` to match hacPack. |
| **HIGH** | `lib/services/nca_builder.dart:47, 587` | PFS0 hash-table padding boundary is `0x4000` and block size is a uniform `0x8000` for all PFS0 sections. | Deviates from hacPack (`0x200` padding; `0x10000` ExeFS, `0x1000` Meta/Logo hash blocks). Wastes space and may cause compatibility issues with tools that assume conventional block sizes. | Use `0x200` padding and use different per-section block sizes (`0x10000` ExeFS, `0x1000` Meta). |
| **MEDIUM** | `lib/services/nacp_builder.dart:58-60` | `enableSvcDebug` is written to NACP `0x3036` (`DataLossConfirmation`) and **never** patched into the NPDM. | The UI toggle has no effect on SVC debug capability, and it incorrectly flips a data-loss confirmation bit. | Either remove the NACP write or implement real NPDM/ACID capability patching; do not use `0x3036` for this. |
| **MEDIUM** | `lib/services/nsp_generator.dart:54-62` | JPEG quality loop for the 256x256 icon stops at `quality = 10`. | A 256x256 image may still exceed `0x20000` bytes at `quality=10`, producing an icon the home menu rejects. | Continue the loop down to `quality = 1` or throw an explicit error if the icon cannot be compressed below `0x20000`. |
| **MEDIUM** | `lib/services/romfs_builder.dart:33-52` and `forwarder_stub_template.dart` | `nextArgv` and `nextNroPath` are built without path-length caps, quote escaping, or null-byte filtering. | Very long or adversarial NRO/ROM paths can corrupt the forwarder argument string or overflow the stub's internal buffer (behavior unverified). | Add length limits and shell/argument escaping; document the maximum supported path length. |
| **MEDIUM** | `test/services/nca_builder_test.dart`, `test/nacp_builder_test.dart` | Tests assert incorrect values for CNMT record types and NACP `DataLossConfirmation`. | Test suite gives false confidence and will break once the real bugs are fixed unless tests are corrected first. | Rewrite tests to assert the correct spec values and to verify real invariants (master hashes, hash tables, PFS0 block sizes). |
| **LOW** | `lib/services/nca_builder.dart:59-60, 87, 129, 137, 248, 275` | `fsTypePfs0=2` / `fsTypeRomfs=3` are wrong for the `FsHeader.fs_type` field and the `fsType` parameter is never written. | No functional impact because `partitionType` values (`0`/`1`) are written to the correct offset, but the naming is misleading and a future refactor could reintroduce the wrong values. | Rename parameters to `fsType` / `hashType` correctly and remove the unused `fsType` parameter or use real `FS_TYPE_*` constants. |
| **LOW** | `lib/services/nca_builder.dart:430-442` | `KeyGenerationOld=2` and `KeyGeneration=1` are inconsistent with the documented NCA3 key-generation table. | Plaintext NCA may still install on CFW, but the header is not spec-compliant. | Set `KeyGenerationOld`/`KeyGeneration` consistently for a low/plaintext generation, or derive from `ProdKeys` if encryption is implemented. |
| **LOW** | `lib/services/nsp_generator.dart` | `ProdKeys` is passed to `generateNsp` but never consumed. | Invalid/missing keys do not prevent NSP generation; the UI key-validation is a no-op at build time. | Either use the keys to encrypt/sign or remove the parameter and centralize validation. |
| **LOW** | requested `lib/services/pfs0_builder.dart` | File does not exist; PFS0 logic is duplicated in `nsp_generator.dart` and `forwarder_stub_template.dart`. | Maintenance burden and risk of divergence between ExeFS and outer NSP PFS0 implementations. | Create a single `Pfs0Builder` service and share it. |
| **LOW** | `lib/services/nacp_builder.dart:23-35` | Title/publisher are silently truncated by byte length, potentially splitting multi-byte UTF-8 sequences. | NACP may contain invalid UTF-8, causing the Switch UI to display garbage or reject the control data. | Truncate on UTF-8 character boundaries or limit the string in the UI. |

---

## 5. Edge-Case Assessment

| Scenario | Current Behavior | Risk |
|----------|------------------|------|
| Very large user icon (> 8K source) | Decoded and resized to 256x256; quality reduced only to 10. May still exceed 0x20000. | Home-menu icon rejection / OOM on low-end devices. |
| Long NRO/ROM paths (> 4096 chars) | Written verbatim into RomFS; `nextArgv` becomes huge. | Forwarder stub buffer overflow; malformed `argv`. |
| Special characters in title/author (`"`, control chars, emoji) | NACP bytes truncated mid-sequence if length limit hit; NSP filename stripped by regex. | Invalid UTF-8 in NACP; empty filename if only special chars. |
| Invalid / missing prod.keys | Parser returns `isValid=false` if empty, but `NspGenerator` does not use keys anyway. | User sees a valid-looking NSP that is still plaintext and unsigned; UI misleading. |
| Missing icon/image bytes | A placeholder JPEG is generated. | Acceptable fallback, but same quality-loop bug applies. |
| Invalid title ID (non-hex, > 16 chars) | `BigInt.tryParse` returns `0`, which is then patched into NPDM and NACP. | Generates a title-id-zero forwarder, which will clash with other zero-id NSPs. |

---

## 6. Prioritized Action Roadmap

### Immediate (P0 — blocks real-world deployment)
1. **Fix CNMT record types** in `nca_builder.dart` and the corresponding tests.
2. **Fix IVFC `MasterHash` offset** — insert the missing `0x20` reserved/signature-salt area and write the master hash at `FsHeader 0xC8` (`IVFC 0xC0`).
3. **Fix PFS0 `MasterHash` computation** — hash the raw, unpadded hash table, not the padded one.
4. After P0 fixes, regenerate a known-good reference NSP and validate it with `hactool --verify` or an equivalent reference parser.

### Short-term (P1 — compatibility and correctness)
5. Refactor PFS0 construction into a single `pfs0_builder.dart` with per-section block sizes (`0x10000` ExeFS, `0x1000` Meta) and `0x200` hash-table padding.
6. Fix `NacpBuilder` so `enableSvcDebug` either actually patches the NPDM or is removed from NACP; do not repurpose `DataLossConfirmation`.
7. Fix the icon JPEG quality loop to terminate at `quality = 1` or enforce a hard `< 0x20000` failure.
8. Add input validation for title ID (exactly 16 hex chars), NRO/ROM path length, and NACP title/publisher UTF-8 boundaries.

### Medium-term (P2 — test and hardening)
9. Rewrite the unit tests to check **real binary invariants**: master hashes, hash-table verification, CNMT record types, NACP field semantics, and PFS0 block sizes.
10. Add negative tests for the edge cases above.
11. Add a known-good reference fixture and compare generated byte ranges against it.

### Long-term (P3 — design)
12. Decide whether the project will produce signed/encrypted NCAs. If yes, wire `ProdKeys` into encryption and NPDM/NCA signing; if no, remove the unused `keys` parameter and document that output is unsigned plaintext intended only for homebrew CFW.

---

## 7. Conclusion

The NSPFF generators are well-organized and implement the *shape* of the Switch formats, but the implementation currently fails on three hard invariants: CNMT content types are swapped, the IVFC master hash is at the wrong offset, and the PFS0 master hash is computed over the wrong data. Because these defects are present in every generated NSP and are not caught by the existing tests, the overall capability/spec-compliance score is **48 / 100**. Fixing the P0 items above and adding reference-based tests is essential before the output can be considered structurally valid and safe for Switch CFW.

---

**Report written to:** `/Users/mey/NSPFF/ciel_audit_capability.md`
