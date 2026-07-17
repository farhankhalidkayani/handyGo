import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_services.dart';
import 'home_screen.dart';
import 'language_select_screen.dart';
import 'profile_setup_screen.dart';

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

    final profile = await AppServices.profiles.findByAuthId(authUser.$id);
    if (!mounted) return;

    if (profile != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)),
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString(languagePrefKey) ?? 'en';
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            authId: authUser.$id,
            email: authUser.email,
            language: language,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
