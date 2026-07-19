import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import 'screens/splash_screen.dart';

void main() {
  runApp(const HandyGoCustomerApp());
}

class HandyGoCustomerApp extends StatelessWidget {
  const HandyGoCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handy Go — Customer',
      theme: buildAppTheme(seedColor: Colors.deepPurple, brightness: Brightness.light),
      darkTheme: buildAppTheme(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
