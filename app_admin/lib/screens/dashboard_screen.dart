import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'ai_insights_body.dart';
import 'analytics_body.dart';
import 'auth_screen.dart';
import 'bookings_screen.dart';
import 'finance_body.dart';
import 'fraud_reports_body.dart';
import 'notifications_body.dart';
import 'operations_map_body.dart';
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
  'Live operations map',
  'Finance',
  'AI Insights',
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

  static const _icons = [
    (Icons.verified_user_outlined, Icons.verified_user),
    (Icons.list_alt_outlined, Icons.list_alt),
    (Icons.sos_outlined, Icons.sos),
    (Icons.report_problem_outlined, Icons.report_problem),
    (Icons.notifications_outlined, Icons.notifications),
    (Icons.bar_chart_outlined, Icons.bar_chart),
    (Icons.map_outlined, Icons.map),
    (Icons.account_balance_outlined, Icons.account_balance),
    (Icons.insights_outlined, Icons.insights),
  ];

  @override
  Widget build(BuildContext context) {
    final isSos = _tab == 2;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        backgroundColor: isSos ? Colors.red.shade700 : null,
        foregroundColor: isSos ? Colors.white : null,
        iconTheme: isSos ? const IconThemeData(color: Colors.white) : null,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context))],
      ),
      drawer: NavigationDrawer(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          Navigator.of(context).pop();
        },
        children: [
          DrawerHeader(
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, size: 32, color: scheme.primary),
                const SizedBox(width: 12),
                Text('Handy Go — Admin', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          for (var i = 0; i < _titles.length; i++)
            NavigationDrawerDestination(
              icon: Icon(_icons[i].$1),
              selectedIcon: Icon(_icons[i].$2),
              label: Text(_titles[i]),
            ),
        ],
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
          OperationsMapBody(),
          FinanceBody(),
          AiInsightsBody(),
        ],
      ),
    );
  }
}
