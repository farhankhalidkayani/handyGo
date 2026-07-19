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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Center')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Safety tips',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: _safetyTips
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(t)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportFraudScreen(reportedById: profile.id),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.errorContainer,
                      child: Icon(
                        Icons.flag_outlined,
                        color: scheme.onErrorContainer,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Report fraud or a bad experience',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Not urgent — reviewed by an admin, not instant',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.emergency_outlined,
                  color: Colors.red.shade700,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  'In immediate danger?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.red.shade700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Press and hold the button below for 3 seconds to alert an admin immediately.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                SosButton(raisedByRole: 'worker', raisedById: profile.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
