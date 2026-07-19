import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_services.dart';
import 'language_select_screen.dart';
import 'post_auth_router.dart';

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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LanguageSelectScreen()),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString(languagePrefKey) ?? 'en';
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PostAuthRouter(authId: authUser.$id, email: authUser.email, language: language),
      ),
    );
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
              child: Icon(Icons.engineering_outlined, size: 40, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Handy Go — Worker', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
