// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/keys_service.dart';
import 'services/network_install_service.dart';
import 'theme/switch_theme.dart';
import 'theme/switch_icons.dart';
import 'theme/switch_gamepad_navigation.dart';
import 'views/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize IconicMorph resolver for custom Material Icon paths
  SwitchIcons.initResolver();

  final keysService = KeysService();
  await keysService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: keysService),
        ChangeNotifierProvider.value(value: NetworkInstallService.instance),
      ],
      child: const NspffApp(),
    ),
  );
}

class NspffApp extends StatelessWidget {
  const NspffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSPFF (NSP Fast Forward)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.6,
            ),
          ),
          child: child!,
        );
      },
      home: const SwitchGamepadScope(
        child: MainNavigationScreen(),
      ),
    );
  }
}
