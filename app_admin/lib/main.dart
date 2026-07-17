import 'package:flutter/material.dart';

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
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const SplashScreen(),
    );
  }
}
