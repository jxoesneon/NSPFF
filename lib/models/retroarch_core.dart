class RetroArchCore {
  final String id;
  final String displayName;
  final String systemName;
  final String coreFilename;
  final String defaultPath;
  final String category;

  const RetroArchCore({
    required this.id,
    required this.displayName,
    required this.systemName,
    required this.coreFilename,
    required this.defaultPath,
    required this.category,
  });

  static const List<RetroArchCore> builtInCores = [
    // Nintendo
    RetroArchCore(
      id: 'snes9x',
      displayName: 'Snes9x (Super Nintendo)',
      systemName: 'Super Nintendo (SNES)',
      coreFilename: 'snes9x_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/snes9x_libretro_libswitch.nro',
      category: 'Nintendo',
    ),
    RetroArchCore(
      id: 'mgba',
      displayName: 'mGBA (Game Boy Advance)',
      systemName: 'Game Boy Advance (GBA)',
      coreFilename: 'mgba_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/mgba_libretro_libswitch.nro',
      category: 'Nintendo',
    ),
    RetroArchCore(
      id: 'mupen64plus_next',
      displayName: 'Mupen64Plus-Next (Nintendo 64)',
      systemName: 'Nintendo 64 (N64)',
      coreFilename: 'mupen64plus_next_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/mupen64plus_next_libretro_libswitch.nro',
      category: 'Nintendo',
    ),
    RetroArchCore(
      id: 'nestopia',
      displayName: 'Nestopia UE (NES / Famicom)',
      systemName: 'Nintendo Entertainment System',
      coreFilename: 'nestopia_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/nestopia_libretro_libswitch.nro',
      category: 'Nintendo',
    ),
    RetroArchCore(
      id: 'fceumm',
      displayName: 'FCEUmm (NES / Famicom)',
      systemName: 'Nintendo Entertainment System',
      coreFilename: 'fceumm_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/fceumm_libretro_libswitch.nro',
      category: 'Nintendo',
    ),
    RetroArchCore(
      id: 'sameboy',
      displayName: 'SameBoy (GB / GBC)',
      systemName: 'Game Boy / Game Boy Color',
      coreFilename: 'sameboy_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/sameboy_libretro_libswitch.nro',
      category: 'Nintendo',
    ),
    RetroArchCore(
      id: 'gambatte',
      displayName: 'Gambatte (GB / GBC)',
      systemName: 'Game Boy / Game Boy Color',
      coreFilename: 'gambatte_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/gambatte_libretro_libswitch.nro',
      category: 'Nintendo',
    ),
    RetroArchCore(
      id: 'desmume',
      displayName: 'DeSmuME (Nintendo DS)',
      systemName: 'Nintendo DS (NDS)',
      coreFilename: 'desmume_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/desmume_libretro_libswitch.nro',
      category: 'Nintendo',
    ),
    RetroArchCore(
      id: 'melonds',
      displayName: 'melonDS (Nintendo DS)',
      systemName: 'Nintendo DS (NDS)',
      coreFilename: 'melonds_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/melonds_libretro_libswitch.nro',
      category: 'Nintendo',
    ),
    RetroArchCore(
      id: 'citra',
      displayName: 'Citra (Nintendo 3DS)',
      systemName: 'Nintendo 3DS',
      coreFilename: 'citra_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/citra_libretro_libswitch.nro',
      category: 'Nintendo',
    ),

    // Sony
    RetroArchCore(
      id: 'pcsx_rearmed',
      displayName: 'PCSX ReARMed (PlayStation 1)',
      systemName: 'PlayStation (PS1)',
      coreFilename: 'pcsx_rearmed_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/pcsx_rearmed_libretro_libswitch.nro',
      category: 'Sony',
    ),
    RetroArchCore(
      id: 'duckstation',
      displayName: 'DuckStation (PlayStation 1)',
      systemName: 'PlayStation (PS1)',
      coreFilename: 'duckstation_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/duckstation_libretro_libswitch.nro',
      category: 'Sony',
    ),
    RetroArchCore(
      id: 'ppsspp',
      displayName: 'PPSSPP (PlayStation Portable)',
      systemName: 'PlayStation Portable (PSP)',
      coreFilename: 'ppsspp_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/ppsspp_libretro_libswitch.nro',
      category: 'Sony',
    ),

    // Sega
    RetroArchCore(
      id: 'genesis_plus_gx',
      displayName: 'Genesis Plus GX (Genesis/MD/Sega CD/Master System)',
      systemName: 'Sega Genesis / Mega Drive',
      coreFilename: 'genesis_plus_gx_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/genesis_plus_gx_libretro_libswitch.nro',
      category: 'Sega',
    ),
    RetroArchCore(
      id: 'picodrive',
      displayName: 'PicoDrive (Genesis / 32X)',
      systemName: 'Sega Genesis / 32X / Sega CD',
      coreFilename: 'picodrive_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/picodrive_libretro_libswitch.nro',
      category: 'Sega',
    ),
    RetroArchCore(
      id: 'yabause',
      displayName: 'Yabause / Kronos (Sega Saturn)',
      systemName: 'Sega Saturn',
      coreFilename: 'yabause_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/yabause_libretro_libswitch.nro',
      category: 'Sega',
    ),
    RetroArchCore(
      id: 'flycast',
      displayName: 'Flycast (Sega Dreamcast / NAOMI)',
      systemName: 'Sega Dreamcast / NAOMI',
      coreFilename: 'flycast_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/flycast_libretro_libswitch.nro',
      category: 'Sega',
    ),

    // Arcade & MAME
    RetroArchCore(
      id: 'fbneo',
      displayName: 'FinalBurn Neo (Arcade)',
      systemName: 'Arcade (FBNeo)',
      coreFilename: 'fbneo_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/fbneo_libretro_libswitch.nro',
      category: 'Arcade',
    ),
    RetroArchCore(
      id: 'fbalpha2012',
      displayName: 'FB Alpha 2012 (Arcade)',
      systemName: 'Arcade (FBA)',
      coreFilename: 'fbalpha2012_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/fbalpha2012_libretro_libswitch.nro',
      category: 'Arcade',
    ),
    RetroArchCore(
      id: 'mame2003_plus',
      displayName: 'MAME 2003-Plus (Arcade)',
      systemName: 'Arcade (MAME 0.78)',
      coreFilename: 'mame2003_plus_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/mame2003_plus_libretro_libswitch.nro',
      category: 'Arcade',
    ),

    // SNK / NEC / Others
    RetroArchCore(
      id: 'beetle_pce_fast',
      displayName: 'Beetle PCE Fast (PC Engine / TurboGrafx-16)',
      systemName: 'PC Engine / TurboGrafx-16',
      coreFilename: 'beetle_pce_fast_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/beetle_pce_fast_libretro_libswitch.nro',
      category: 'NEC',
    ),
    RetroArchCore(
      id: 'beetle_ngp',
      displayName: 'Beetle NeoPop (Neo Geo Pocket)',
      systemName: 'Neo Geo Pocket / Color',
      coreFilename: 'beetle_ngp_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/beetle_ngp_libretro_libswitch.nro',
      category: 'SNK',
    ),
    RetroArchCore(
      id: 'stella',
      displayName: 'Stella (Atari 2600)',
      systemName: 'Atari 2600',
      coreFilename: 'stella_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/stella_libretro_libswitch.nro',
      category: 'Atari',
    ),
    RetroArchCore(
      id: 'prosystem',
      displayName: 'ProSystem (Atari 7800)',
      systemName: 'Atari 7800',
      coreFilename: 'prosystem_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/prosystem_libretro_libswitch.nro',
      category: 'Atari',
    ),
    RetroArchCore(
      id: 'scummvm',
      displayName: 'ScummVM (Point and Click Games)',
      systemName: 'ScummVM Engine',
      coreFilename: 'scummvm_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/scummvm_libretro_libswitch.nro',
      category: 'PC',
    ),
    RetroArchCore(
      id: 'dosbox_pure',
      displayName: 'DOSBox Pure (MS-DOS)',
      systemName: 'MS-DOS',
      coreFilename: 'dosbox_pure_libretro_libswitch.nro',
      defaultPath: '/retroarch/cores/dosbox_pure_libretro_libswitch.nro',
      category: 'PC',
    ),
  ];
}
