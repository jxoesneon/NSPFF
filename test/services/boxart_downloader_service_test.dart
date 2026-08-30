// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:nspff/services/boxart_downloader_service.dart';

void main() {
  group('BoxartDownloaderService', () {
    test('getBoxartUrl returns null for unsupported systems', () {
      expect(BoxartDownloaderService.getBoxartUrl('Unknown System', 'Game'), isNull);
    });

    test('getBoxartUrl returns null for empty ROM title', () {
      expect(
        BoxartDownloaderService.getBoxartUrl('Super Nintendo (SNES)', ''),
        isNull,
      );
    });

    test('getBoxartUrl builds Libretro CDN URL for supported system and title',
        () {
      final url = BoxartDownloaderService.getBoxartUrl(
        'Super Nintendo (SNES)',
        'Super Mario World',
      );
      expect(url, isNotNull);
      expect(
        url,
        contains(
          'Nintendo_-_Super_Nintendo_Entertainment_System/Named_Boxarts/',
        ),
      );
      expect(url, contains('Super%20Mario%20World.png'));
    });

    test('fetchBoxartImage returns null without network call for invalid inputs',
        () async {
      final result =
          await BoxartDownloaderService.fetchBoxartImage('Unknown', 'Game');
      expect(result, isNull);
    });
  });
}
