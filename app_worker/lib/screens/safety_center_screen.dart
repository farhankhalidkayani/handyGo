import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../widgets/sos_button.dart';
import 'report_fraud_screen.dart';

const _safetyTips = [
  'Verify the customer\'s name matches the booking before entering any premises.',
  'Never accept payment outside the app — HandyGo only supports in-app cash-on-completion for now.',
  'Keep your location sharing on while heading to a job so support can find you if needed.',
  'If you feel unsafe at any point, press and hold the SOS button below for 3 seconds.',
];

/// Plan §12 checklist: "Safety Center + SOS + Report Fraud" — a single hub tying together
/// the SOS button and fraud reporting that otherwise only appear inline on an active job.
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
          Center(child: SosButton(raisedByRole: 'worker', raisedById: profile.id)),
        ],
      ),
    );
  }
}
