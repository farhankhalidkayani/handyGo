import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import 'screens/splash_screen.dart';

void main() {
  runApp(const HandyGoAdminApp());
}

class HandyGoAdminApp extends StatelessWidget {
  const HandyGoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handy Go — Admin',
      theme: buildAppTheme(seedColor: Colors.indigo, brightness: Brightness.light),
      darkTheme: buildAppTheme(seedColor: Colors.indigo, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
