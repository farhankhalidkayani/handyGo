import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_screen.dart';

const languagePrefKey = 'handygo_language';

class LanguageSelectScreen extends StatelessWidget {
  const LanguageSelectScreen({super.key});

  Future<void> _select(BuildContext context, String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(languagePrefKey, code);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => AuthScreen(language: code)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Handy Go — Worker',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const Text('Choose your language', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _select(context, 'en'),
              child: const Text('English'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _select(context, 'ur'),
              child: const Text('اردو'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _select(context, 'roman_ur'),
              child: const Text('Roman Urdu'),
            ),
          ],
        ),
      ),
    );
  }
}
