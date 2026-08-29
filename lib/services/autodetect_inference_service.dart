// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:path/path.dart' as p;
import '../models/retroarch_core.dart';
import '../widgets/title_id_input.dart';

class RomInferenceResult {
  final String title;
  final String publisher;
  final RetroArchCore? core;
  final String corePath;
  final String romSdPath;
  final String titleId;

  RomInferenceResult({
    required this.title,
    required this.publisher,
    required this.core,
    required this.corePath,
    required this.romSdPath,
    required this.titleId,
  });
}

class NroInferenceResult {
  final String title;
  final String publisher;
  final String nroSdPath;
  final String titleId;

  NroInferenceResult({
    required this.title,
    required this.publisher,
    required this.nroSdPath,
    required this.titleId,
  });
}

class AutodetectInferenceService {
  /// File extension to system mapping & default RetroArch core ID
  static const Map<String, Map<String, String>> _extMapping = {
    '.sfc': {'system': 'Super Nintendo (SNES)', 'coreId': 'snes9x', 'sdDir': '/roms/snes/'},
    '.smc': {'system': 'Super Nintendo (SNES)', 'coreId': 'snes9x', 'sdDir': '/roms/snes/'},
    '.gba': {'system': 'Game Boy Advance (GBA)', 'coreId': 'mgba', 'sdDir': '/roms/gba/'},
    '.gb': {'system': 'Game Boy / Game Boy Color', 'coreId': 'sameboy', 'sdDir': '/roms/gb/'},
    '.gbc': {'system': 'Game Boy / Game Boy Color', 'coreId': 'sameboy', 'sdDir': '/roms/gbc/'},
    '.z64': {'system': 'Nintendo 64 (N64)', 'coreId': 'mupen64plus_next', 'sdDir': '/roms/n64/'},
    '.n64': {'system': 'Nintendo 64 (N64)', 'coreId': 'mupen64plus_next', 'sdDir': '/roms/n64/'},
    '.v64': {'system': 'Nintendo 64 (N64)', 'coreId': 'mupen64plus_next', 'sdDir': '/roms/n64/'},
    '.nes': {'system': 'Nintendo Entertainment System', 'coreId': 'nestopia', 'sdDir': '/roms/nes/'},
    '.fds': {'system': 'Nintendo Entertainment System', 'coreId': 'nestopia', 'sdDir': '/roms/fds/'},
    '.nds': {'system': 'Nintendo DS (NDS)', 'coreId': 'melonds', 'sdDir': '/roms/nds/'},
    '.3ds': {'system': 'Nintendo 3DS', 'coreId': 'citra', 'sdDir': '/roms/3ds/'},
    '.iso': {'system': 'PlayStation (PS1)', 'coreId': 'pcsx_rearmed', 'sdDir': '/roms/psx/'},
    '.bin': {'system': 'PlayStation (PS1)', 'coreId': 'pcsx_rearmed', 'sdDir': '/roms/psx/'},
    '.cue': {'system': 'PlayStation (PS1)', 'coreId': 'pcsx_rearmed', 'sdDir': '/roms/psx/'},
    '.chd': {'system': 'PlayStation (PS1)', 'coreId': 'pcsx_rearmed', 'sdDir': '/roms/psx/'},
    '.pbp': {'system': 'PlayStation Portable (PSP)', 'coreId': 'ppsspp', 'sdDir': '/roms/psp/'},
    '.cso': {'system': 'PlayStation Portable (PSP)', 'coreId': 'ppsspp', 'sdDir': '/roms/psp/'},
    '.md': {'system': 'Sega Genesis / Mega Drive', 'coreId': 'genesis_plus_gx', 'sdDir': '/roms/genesis/'},
    '.gen': {'system': 'Sega Genesis / Mega Drive', 'coreId': 'genesis_plus_gx', 'sdDir': '/roms/genesis/'},
    '.smd': {'system': 'Sega Genesis / Mega Drive', 'coreId': 'genesis_plus_gx', 'sdDir': '/roms/genesis/'},
    '.pce': {'system': 'PC Engine / TurboGrafx-16', 'coreId': 'beetle_pce_fast', 'sdDir': '/roms/pce/'},
    '.zip': {'system': 'Arcade (FBNeo)', 'coreId': 'fbneo', 'sdDir': '/roms/arcade/'},
  };

  static final RegExp _parensTagRegex = RegExp(r'\s*\([^)]*\)');
  static final RegExp _bracketTagRegex = RegExp(r'\s*\[[^\]]*\]');

  /// Clean ROM filename by stripping dump tags like (USA), [!], (v1.1), (Rev 1), etc.
  static String cleanTitle(String input) {
    String name = p.basenameWithoutExtension(input.trim());

    // Regex stripping parentheses tags like (USA), (Europe), (Japan), (En,Fr,De)
    name = name.replaceAll(_parensTagRegex, '');

    // Regex stripping bracket tags like [!], [b1], [t1], [h1]
    name = name.replaceAll(_bracketTagRegex, '');

    // Replace underscores with spaces
    name = name.replaceAll('_', ' ');

    return name.trim();
  }

  /// Auto-detect all fields for a ROM path or filename.
  static RomInferenceResult inferRomDetails(String inputPath) {
    final cleanName = cleanTitle(inputPath);
    final ext = p.extension(inputPath).toLowerCase();
    
    final map = _extMapping[ext];
    RetroArchCore? matchedCore;
    String sdDir = '/roms/games/';
    String publisher = 'RetroArch';

    if (map != null) {
      final coreId = map['coreId'];
      sdDir = map['sdDir'] ?? '/roms/games/';
      publisher = '${map['system']} / RetroArch';

      try {
        matchedCore = RetroArchCore.builtInCores.firstWhere((c) => c.id == coreId);
      } catch (_) {}
    }

    final filename = p.basename(inputPath);
    final romSdPath = '$sdDir$filename';
    final titleId = TitleIdInput.generateRandomID();

    return RomInferenceResult(
      title: cleanName.isNotEmpty ? cleanName : 'Retro Game',
      publisher: publisher,
      core: matchedCore,
      corePath: matchedCore?.defaultPath ?? '/retroarch/cores/snes9x_libretro_libswitch.nro',
      romSdPath: romSdPath,
      titleId: titleId,
    );
  }

  /// Auto-detect all fields for an NRO path or file.
  static NroInferenceResult inferNroDetails(String inputPath) {
    final cleanName = cleanTitle(inputPath);
    final filename = p.basename(inputPath);
    final nroSdPath = '/switch/$filename';
    final titleId = TitleIdInput.generateRandomID();

    return NroInferenceResult(
      title: cleanName.isNotEmpty ? cleanName : 'Homebrew App',
      publisher: 'Switch Homebrew',
      nroSdPath: nroSdPath,
      titleId: titleId,
    );
  }
}
