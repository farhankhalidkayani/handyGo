import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'language_select_screen.dart';

class DashboardScreen extends StatelessWidget {
  final UserProfile profile;
  final WorkerProfile worker;

  const DashboardScreen({super.key, required this.profile, required this.worker});

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
        title: const Text('Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${profile.name}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Skills: ${worker.skills.join(', ')}'),
            Text('Rating: ${worker.rating.toStringAsFixed(1)} · Jobs completed: ${worker.jobsCompleted}'),
            const SizedBox(height: 24),
            const Text(
              'Online toggle, incoming requests, navigation and earnings are next — this '
              'screen confirms auth + worker registration + verification are wired end-to-end.',
            ),
          ],
        ),
      ),
    );
  }
}
