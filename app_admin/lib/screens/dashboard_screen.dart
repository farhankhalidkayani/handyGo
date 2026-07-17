import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'analytics_body.dart';
import 'auth_screen.dart';
import 'bookings_screen.dart';
import 'fraud_reports_body.dart';
import 'notifications_body.dart';
import 'sos_control_center_body.dart';
import 'verification_queue_body.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

const _titles = [
  'Worker verification queue',
  'Live bookings',
  'SOS Control Center',
  'Fraud reports',
  'Notifications',
  'Analytics',
];

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
        title: Text(_titles[_tab]),
        backgroundColor: _tab == 2 ? Colors.red.shade700 : null,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context))],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          VerificationQueueBody(),
          BookingsBody(),
          SosControlCenterBody(),
          FraudReportsBody(),
          NotificationsBody(),
          AnalyticsBody(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.verified_user), label: 'Verify'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.sos), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.report_problem), label: 'Fraud'),
          NavigationDestination(icon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Analytics'),
        ],
      ),
    );
  }
}
