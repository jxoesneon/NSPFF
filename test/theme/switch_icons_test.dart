// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:iconic_morph/iconic_morph.dart';
import 'package:nspff/theme/switch_icons.dart';

void main() {
  setUp(() {
    SwitchIcons.initResolver();
  });

  tearDown(() {
    IconGeometry.evict();
    IconGeometry.resolver = null;
  });

  group('SwitchIcons resolver', () {
    test('Resolver returns null for unknown assets', () async {
      final result = await IconGeometry.resolver?.call('custom:unknown');
      expect(result, isNull);
    });
  });

  group('SwitchIcons exported icons', () {
    testWidgets('plus icon loads with valid geometry', (tester) async {
      final geometry = await IconGeometry.load(SwitchIcons.plus);
      expect(geometry, isNotNull);
      expect(geometry.viewBox, greaterThan(0));
      expect(geometry.contours, isNotEmpty);
      expect(geometry.totalLength, greaterThan(0));
    });

    testWidgets('check icon loads with valid geometry', (tester) async {
      final geometry = await IconGeometry.load(SwitchIcons.check);
      expect(geometry, isNotNull);
      expect(geometry.viewBox, greaterThan(0));
      expect(geometry.contours, isNotEmpty);
      expect(geometry.totalLength, greaterThan(0));
    });

    testWidgets('key icon loads with valid geometry', (tester) async {
      final geometry = await IconGeometry.load(SwitchIcons.key);
      expect(geometry, isNotNull);
      expect(geometry.viewBox, greaterThan(0));
      expect(geometry.contours, isNotEmpty);
      expect(geometry.totalLength, greaterThan(0));
    });

    testWidgets('keyOff icon loads with valid geometry', (tester) async {
      final geometry = await IconGeometry.load(SwitchIcons.keyOff);
      expect(geometry, isNotNull);
      expect(geometry.viewBox, greaterThan(0));
      expect(geometry.contours, isNotEmpty);
      expect(geometry.totalLength, greaterThan(0));
    });
  });
}
