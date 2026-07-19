import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';
import 'not_authorized_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final authUser = await AppServices.auth.getCurrentUser();
    if (!mounted) return;

    if (authUser == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }

    final profile = await AppServices.profiles.findByAuthId(authUser.$id);
    if (!mounted) return;

    if (profile != null && profile.role == UserRole.admin) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const NotAuthorizedScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.admin_panel_settings_outlined, size: 40, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Handy Go — Admin', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
