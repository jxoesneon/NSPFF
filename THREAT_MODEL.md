# Threat Model & Risk Assessment: NSPFF

## Overview
This document outlines the formal STRIDE threat model for **NSPFF (NSP Fast Forward)**, analyzing potential security risks associated with container generation, cryptographic key handling, path input processing, and console execution.

---

## Trust Boundaries

```
+-------------------------------------------------------------------+
|                        ANDROID HANDHELD DEVICE                    |
|                                                                   |
| [ User Input ] ----> [ NSPFF Application Sandboxed Context ]      |
|                             |                                     |
|                             v                                     |
|                    [ Local Storage ]                              |
+-------------------------------------------------------------------+
                              | (USB / SD Card Transfer)
                              v
+-------------------------------------------------------------------+
|                     NINTENDO SWITCH CONSOLE                       |
|                                                                   |
| [ Atmosphere CFW ] ----> [ DBI / Awoo Installer ]                 |
|                             |                                     |
|                             v                                     |
|                    [ Horizon OS NAND / SD ]                       |
+-------------------------------------------------------------------+
```

---

## STRIDE Threat Matrix

| Threat Category | Description | Risk Level | Mitigation Strategy |
|---|---|---|---|
| **Spoofing** | Malicious Title ID colliding with system application IDs | Medium | NSPFF restricts default Title ID generation to user-space ranges (`0x0500...`) and validates hex formatting. |
| **Tampering** | Corruption of `.nsp` container structures leading to installation error 2016-1263 | Medium | Enforces `0x20` byte PFS0 alignment and Little-Endian byte serialization across all binary headers. |
| **Repudiation** | Unverified generation history | Low | Maintains persistent local transaction history of created forwarders in app storage. |
| **Information Disclosure** | Leakage of user `prod.keys` or cryptographic header keys | High | Keys are processed strictly in-memory or in sandboxed app storage. Telemetry is non-existent. |
| **Denial of Service** | Application crash due to malformed `.nro` binary payload | Low | `NroParser` checks `NRO0` and `ASET` magic signatures and validates buffer bounds before indexing. |
| **Elevation of Privilege** | Execution of arbitrary system code on console | High | Forwarders only issue standard `applet` launch calls to target SD card paths (`/switch/*.nro`). |

---

## Console Ban Risk & Mitigations

Installing custom NSP packages updates the Switch system ticket database. 
* **Mitigation Guidance:** NSPFF documentation explicitly requires operating on an offline **emuMMC** with **DNS MITM** (`default.txt`) or **Exosphere** (`exosphere.ini`) enabled to blank serial numbers and block Nintendo telemetry endpoints.
