import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'auth_screen.dart';

class NotAuthorizedScreen extends StatelessWidget {
  const NotAuthorizedScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AppServices.auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.block, size: 48, color: Colors.red),
              ),
              const SizedBox(height: 20),
              Text(
                'This account does not have admin access.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
