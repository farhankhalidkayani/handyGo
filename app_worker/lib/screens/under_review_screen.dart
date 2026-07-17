import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'language_select_screen.dart';

class UnderReviewScreen extends StatelessWidget {
  final String status;

  const UnderReviewScreen({super.key, required this.status});

  String get _message {
    switch (status) {
      case 'rejected':
        return 'Your application was not approved. Contact support for details.';
      case 'suspended':
        return 'Your account is suspended. Contact support for details.';
      default:
        return 'Your documents are under review. This usually takes 1-2 business days — '
            'you will be notified once approved.';
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AppServices.auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LanguageSelectScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 64),
              const SizedBox(height: 16),
              Text(_message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
