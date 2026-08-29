import 'package:flutter/material.dart';
import 'theme/switch_theme.dart';
import 'views/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NspffApp());
}

class NspffApp extends StatelessWidget {
  const NspffApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSPFF (NSP Fast Forward)',
      debugShowCheckedModeBanner: false,
      theme: SwitchTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}
