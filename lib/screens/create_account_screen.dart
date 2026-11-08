import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../services/gundua_api_client.dart';
import 'main_navigation_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  static const Color background = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF111111);
  static const Color secondaryColor = Color(0xFF767676);
  static const Color accentColor = Color(0xFFFF5A5F);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final ProfileService _profileService = ProfileService();

  bool _hidePassword = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await _profileService.createLocalAccount(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: secondaryColor, size: 21),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFEDEEEF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: textColor, width: 1.2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 12, 26, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Faz parte\ndas descobertas.',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 36,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      GunduaApiClient.isConfigured
                          ? 'Cria a tua conta GUNDUA no servidor.'
                          : 'Cria o teu perfil GUNDUA neste dispositivo.',
                      style: TextStyle(color: secondaryColor, fontSize: 14),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration('Nome completo', Icons.person_outline),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Indica o teu nome.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration('Email', Icons.mail_outline),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                            ? null
                            : 'Indica um email válido.';
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: _decoration('Palavra-passe', Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8
                          ? 'Usa pelo menos 8 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: _decoration('Confirmar palavra-passe', Icons.verified_user_outlined),
                      validator: (value) => value != _passwordController.text
                          ? 'As palavras-passe não coincidem.'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Criar conta'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        GunduaApiClient.isConfigured
                            ? 'A conta é guardada no servidor GUNDUA.'
                            : 'Os dados desta conta ficam guardados localmente.',
                        style: TextStyle(color: secondaryColor, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
