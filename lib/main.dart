import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'theme/gundua_theme.dart';

void main() {
  runApp(const GunduaApp());
}

class GunduaApp extends StatelessWidget {
  const GunduaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GUNDUA',
      debugShowCheckedModeBanner: false,
      theme: GunduaTheme.light(),
      home: const SplashScreen(),
    );
  }
}
