import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../services/gundua_api_client.dart';
import 'create_account_screen.dart';
import 'main_navigation_screen.dart';

class WelcomeGetStartedScreen extends StatefulWidget {
  const WelcomeGetStartedScreen({super.key});

  @override
  State<WelcomeGetStartedScreen> createState() => _WelcomeGetStartedScreenState();
}

class _WelcomeGetStartedScreenState extends State<WelcomeGetStartedScreen> {
  static const Color background = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF111111);
  static const Color secondaryColor = Color(0xFF767676);
  static const Color accentColor = Color(0xFFFF5A5F);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ProfileService _profileService = ProfileService();

  bool _hidePassword = true;
  bool _isSigningIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Preenche o email e a palavra-passe.');
      return;
    }

    setState(() => _isSigningIn = true);
    try {
      final signedIn = await _profileService.signInLocally(
        email: email,
        password: password,
      );
      if (!mounted) return;
      setState(() => _isSigningIn = false);
      if (!signedIn) {
        _showMessage(GunduaApiClient.isConfigured
            ? 'Não foi possível entrar. Confirma os teus dados ou cria uma conta GUNDUA.'
            : 'Dados incorretos. Tenta novamente ou cria uma conta neste dispositivo.');
        return;
      }
      _openHome();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSigningIn = false);
      _showMessage(error.toString());
    }
  }

  void _createAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
    );
  }

  void _openHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: secondaryColor),
        prefixIcon: Icon(icon, color: secondaryColor, size: 21),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFEDEEEF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: textColor, width: 1.2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: textColor,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Text(
                      'G',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 44),
                  const Text(
                    'O mundo\nespera por ti.',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 39,
                      height: 1.1,
                      letterSpacing: -1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 34),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('Email', Icons.mail_outline),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    onSubmitted: (_) => _signIn(),
                    decoration: _inputDecoration('Palavra-passe', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: secondaryColor,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSigningIn ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: _isSigningIn
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Entrar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _createAccount,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Criar conta'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: _openHome,
                      child: const Text(
                        'Explorar sem iniciar sessão',
                        style: TextStyle(color: secondaryColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
