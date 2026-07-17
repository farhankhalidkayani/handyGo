import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

void main() {
  runApp(const HandyGoWorkerApp());
}

class HandyGoWorkerApp extends StatelessWidget {
  const HandyGoWorkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handy Go — Worker',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const SplashScreen(),
    );
  }
}
