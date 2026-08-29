import 'package:flutter/material.dart';
import 'theme/switch_theme.dart';
import 'views/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NspForwarderApp());
}

class NspForwarderApp extends StatelessWidget {
  const NspForwarderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSP Forwarder>>',
      debugShowCheckedModeBanner: false,
      theme: SwitchTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}
