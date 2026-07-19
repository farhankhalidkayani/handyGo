import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

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
      theme: buildAppTheme(seedColor: Colors.teal, brightness: Brightness.light),
      darkTheme: buildAppTheme(seedColor: Colors.teal, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
