// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:typed_data';
import 'package:http/http.dart' as http;

class BoxartDownloaderService {
  /// Base URL for Libretro Thumbnail CDN
  static const String _baseLibretroCdn = 'https://raw.githubusercontent.com/libretro/libretro-thumbnails/master/';

  /// Map common system names to Libretro thumbnail repository system directory names
  static const Map<String, String> _systemToCdnDir = {
    'Super Nintendo (SNES)': 'Nintendo_-_Super_Nintendo_Entertainment_System',
    'Game Boy Advance (GBA)': 'Nintendo_-_Game_Boy_Advance',
    'Nintendo 64 (N64)': 'Nintendo_-_Nintendo_64',
    'Nintendo Entertainment System': 'Nintendo_-_Nintendo_Entertainment_System',
    'Game Boy / Game Boy Color': 'Nintendo_-_Game_Boy_Color',
    'Nintendo DS (NDS)': 'Nintendo_-_Nintendo_DS',
    'PlayStation (PS1)': 'Sony_-_PlayStation',
    'PlayStation Portable (PSP)': 'Sony_-_PlayStation_Portable',
    'Sega Genesis / Mega Drive': 'Sega_-_Mega_Drive_-_Genesis',
  };

  /// Constructs the URL for fetching a ROM's cover art from Libretro Boxart CDN.
  static String? getBoxartUrl(String systemName, String romTitle) {
    final cdnDir = _systemToCdnDir[systemName];
    if (cdnDir == null || romTitle.trim().isEmpty) return null;

    final sanitizedTitle = Uri.encodeComponent(romTitle.trim());
    return '$_baseLibretroCdn$cdnDir/Named_Boxarts/$sanitizedTitle.png';
  }

  /// Downloads boxart binary image data from CDN URL.
  static Future<Uint8List?> fetchBoxartImage(String systemName, String romTitle) async {
    final url = getBoxartUrl(systemName, romTitle);
    if (url == null) return null;

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }
}
