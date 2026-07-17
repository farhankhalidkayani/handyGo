import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../widgets/sos_button.dart';
import 'report_fraud_screen.dart';

const _safetyTips = [
  'Always verify the worker\'s name and photo match what\'s shown in the app before letting them in.',
  'Never make a payment outside the app — HandyGo only supports in-app cash-on-completion for now.',
  'Share your live tracking link with a friend or family member for extra safety.',
  'If you feel unsafe at any point, press and hold the SOS button below for 3 seconds.',
];

/// Plan §12 checklist: "Safety Center + SOS + Report Fraud" — a single hub tying together
/// the SOS button and fraud reporting that otherwise only appear inline on an active booking.
class SafetyCenterScreen extends StatelessWidget {
  final UserProfile profile;

  const SafetyCenterScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Center')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Safety tips', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._safetyTips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t)),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report fraud or a bad experience'),
              subtitle: const Text('Not urgent — reviewed by an admin, not instant'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ReportFraudScreen(reportedById: profile.id)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text('In immediate danger?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Press and hold the button below for 3 seconds to alert an admin immediately.'),
          const SizedBox(height: 16),
          Center(child: SosButton(raisedByRole: 'customer', raisedById: profile.id)),
        ],
      ),
    );
  }
}
