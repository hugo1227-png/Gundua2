import 'package:flutter/material.dart';

/// A comunidade ainda não tem backend social na versão alfa.
/// Não apresenta atividades inventadas nem botões sem funcionalidade.
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key, this.hasConnections = false, this.onGoHome});

  final bool hasConnections; // Mantém compatibilidade com usos anteriores.
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comunidade')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'As partilhas dos teus amigos vão aparecer aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                const Text(
                  'A ligação entre viajantes será adicionada numa próxima fase.',
                  textAlign: TextAlign.center,
                ),
                if (onGoHome != null) ...[
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onGoHome, child: const Text('Explorar lugares')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
