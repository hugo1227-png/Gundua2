import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import 'main_navigation_screen.dart';
import 'welcome_get_started_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color background = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF111111);
  static const Color accentColor = Color(0xFFFF5A5F);

  @override
  void initState() {
    super.initState();
    _openWelcomeScreen();
  }

  Future<void> _openWelcomeScreen() async {
    await Future.delayed(const Duration(seconds: 2));
    final isLoggedIn = await ProfileService().isLoggedIn();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => isLoggedIn
            ? const MainNavigationScreen()
            : const WelcomeGetStartedScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: textColor,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'gundua',
              style: TextStyle(
                color: textColor,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 30),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
