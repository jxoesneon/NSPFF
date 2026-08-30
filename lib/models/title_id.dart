// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:math';

import '../services/title_id_registry_service.dart';

/// Generates a cryptographically random 16-hex Title ID in the homebrew
/// 0x05 range, validating it against [TitleIdRegistryService] for
/// collisions before returning.
String generateRandomTitleId() => TitleId.generateRandomId();

/// Domain utility for Nintendo Switch Title ID operations.
class TitleId {
  static const int _maxAttempts = 1000;

  /// Generates a cryptographically random 16-hex Title ID in the homebrew
  /// 0x05 range with the program index (low nibble) forced to 0, validating it
  /// against [TitleIdRegistryService] for collisions before returning.
  static String generateRandomId() {
    final rand = Random.secure();

    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      final buffer = StringBuffer('05');
      // 13 random nibbles in the middle, then force program index (low nibble) to 0.
      for (int i = 0; i < 13; i++) {
        buffer.write(rand.nextInt(16).toRadixString(16).toUpperCase());
      }
      buffer.write('0');
      final candidate = buffer.toString();
      final validation = TitleIdRegistryService.validateTitleId(candidate);
      if (validation.isSafe) return candidate;
    }

    throw StateError(
      'Unable to generate a unique homebrew Title ID after $_maxAttempts attempts.',
    );
  }
}
