import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'auth_screen.dart';
import 'bookings_screen.dart';
import 'verification_queue_body.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;

  Future<void> _logout(BuildContext context) async {
    await AppServices.auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Worker verification queue' : 'Live bookings'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context))],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [VerificationQueueBody(), BookingsBody()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.verified_user), label: 'Verifications'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Bookings'),
        ],
      ),
    );
  }
}
