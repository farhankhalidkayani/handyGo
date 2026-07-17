import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

const _riskColors = {
  'critical': Colors.red,
  'high': Colors.orange,
  'medium': Colors.amber,
  'low': Colors.grey,
};

/// Plan §10.3: "Admin SOS Control Center — red banner + incident timeline + actions (...
/// Mark Safe, Close)". Full action set (Open Live Location, Call parties, Pause Booking,
/// Block Payment, Cancel, Suspend) is a follow-up; this covers acknowledge/in-progress/mark
/// safe/close, which already exercises the real state machine end-to-end.
class SosControlCenterBody extends StatefulWidget {
  const SosControlCenterBody({super.key});

  @override
  State<SosControlCenterBody> createState() => _SosControlCenterBodyState();
}

class _SosControlCenterBodyState extends State<SosControlCenterBody> {
  final List<SosAlert> _alerts = [];
  RealtimeSubscription? _subscription;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = AppServices.sos.subscribeToSosAlerts();
    _subscription!.stream.listen((event) {
      final alert = SosAlert.fromMap(event.payload);
      setState(() {
        final i = _alerts.indexWhere((a) => a.id == alert.id);
        if (i != -1) {
          if (alert.adminStatus == 'closed') {
            _alerts.removeAt(i);
          } else {
            _alerts[i] = alert;
          }
        } else if (alert.adminStatus != 'closed') {
          _alerts.insert(0, alert);
        }
      });
    });
  }

  Future<void> _load() async {
    final alerts = await AppServices.sos.listOpenAlerts();
    if (!mounted) return;
    setState(() {
      _alerts
        ..clear()
        ..addAll(alerts);
      _loading = false;
    });
  }

  Future<void> _updateStatus(SosAlert alert, String status) async {
    setState(() => _error = null);
    try {
      await AppServices.sos.updateStatus(sosAlertId: alert.id, adminStatus: status);
    } catch (e) {
      setState(() => _error = 'Action failed: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        if (_error != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_alerts.isEmpty)
          const Expanded(child: Center(child: Text('No open SOS alerts.')))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _alerts.length,
              itemBuilder: (context, i) {
                final a = _alerts[i];
                final riskColor = _riskColors[a.aiRiskLevel] ?? Colors.grey;
                return Card(
                  color: riskColor.withValues(alpha: 0.1),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${a.emergencyType.toUpperCase()} — ${(a.aiRiskLevel ?? 'unknown').toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Raised by ${a.raisedByRole} ${a.raisedById}'),
                        if (a.aiSummary != null) ...[
                          const SizedBox(height: 8),
                          Text(a.aiSummary!),
                        ],
                        if (a.aiSuggestedActions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: a.aiSuggestedActions.map((s) => Chip(label: Text(s))).toList(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => _updateStatus(a, 'acknowledged'),
                              child: const Text('Acknowledge'),
                            ),
                            OutlinedButton(
                              onPressed: () => _updateStatus(a, 'in_progress'),
                              child: const Text('In progress'),
                            ),
                            FilledButton(
                              onPressed: () => _updateStatus(a, 'safe'),
                              child: const Text('Mark safe'),
                            ),
                            OutlinedButton(
                              onPressed: () => _updateStatus(a, 'closed'),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
