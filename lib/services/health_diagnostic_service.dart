// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import '../models/prod_keys.dart';
import 'keys_service.dart';

class DiagnosticReport {
  final bool keysReady;
  final bool headerKeyPresent;
  final bool sdSeedPresent;
  final bool titleKdkPresent;
  final List<String> issues;

  DiagnosticReport({
    required this.keysReady,
    required this.headerKeyPresent,
    required this.sdSeedPresent,
    required this.titleKdkPresent,
    required this.issues,
  });
}

class HealthDiagnosticService {
  /// Runs complete system diagnostic check on keys and binary readiness.
  static Future<DiagnosticReport> runDiagnostic() async {
    final ProdKeys? keys = await KeysService.loadKeys();
    final List<String> issues = [];

    if (keys == null) {
      issues.add('prod.keys file missing or invalid in app storage.');
    } else {
      if (!keys.hasHeaderKey) {
        issues.add('header_key is missing from prod.keys.');
      }
      if (!keys.hasSdSeed) issues.add('sd_seed is missing from prod.keys.');
      if (!keys.hasTitleKdk) {
        issues.add('titlekdk_00 is missing from prod.keys.');
      }
      if (!keys.isValid && issues.isEmpty) {
        issues.add('prod.keys file missing or invalid in app storage.');
      }
    }

    return DiagnosticReport(
      keysReady: keys != null && keys.isValid,
      headerKeyPresent: keys?.hasHeaderKey ?? false,
      sdSeedPresent: keys?.hasSdSeed ?? false,
      titleKdkPresent: keys?.hasTitleKdk ?? false,
      issues: issues,
    );
  }
}
