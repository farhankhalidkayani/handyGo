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
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'This account does not have admin access.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => _logout(context), child: const Text('Log out')),
            ],
          ),
        ),
      ),
    );
  }
}
