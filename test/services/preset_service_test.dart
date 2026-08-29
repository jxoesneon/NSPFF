// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/models/forwarder_config.dart';
import 'package:nspff/services/preset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedPresetService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Saves config to history and retrieves it', () async {
      final config = ForwarderConfig(
        id: '0500000000000001',
        title: 'History Test Game',
        publisher: 'Dev Team',
        nroPath: '/switch/history.nro',
      );

      await SavedPresetService.addToHistory(config);
      final history = await SavedPresetService.getHistory();

      expect(history, hasLength(1));
      expect(history.first.id, equals('0500000000000001'));
      expect(history.first.title, equals('History Test Game'));
    });

    test('Clears history correctly', () async {
      final config = ForwarderConfig(
        id: '0500000000000002',
        title: 'Clear Test Game',
        publisher: 'Dev Team',
        nroPath: '/switch/clear.nro',
      );

      await SavedPresetService.addToHistory(config);
      await SavedPresetService.clearHistory();
      final history = await SavedPresetService.getHistory();

      expect(history, isEmpty);
    });
  });
}
