import 'package:flutter/material.dart';

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
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const SplashScreen(),
    );
  }
}
