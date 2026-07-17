import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §10.4: "Fraud workflow: report -> evidence -> account flagged -> admin investigation
/// -> both-party response -> decision". AI writes aiSummary/aiRecommendation only (§8.3
/// governance rule — shown here as a recommendation, not auto-applied); admin picks the final
/// adminDecision via the buttons below, which is the only thing that writes it.
class FraudReportsBody extends StatefulWidget {
  const FraudReportsBody({super.key});

  @override
  State<FraudReportsBody> createState() => _FraudReportsBodyState();
}

const _decisions = ['dismissed', 'warning', 'refund', 'suspension', 'ban'];

class _FraudReportsBodyState extends State<FraudReportsBody> {
  final List<FraudReport> _reports = [];
  RealtimeSubscription? _subscription;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = AppServices.fraud.subscribeToFraudReports();
    _subscription!.stream.listen((event) {
      final report = FraudReport.fromMap(event.payload);
      setState(() {
        final i = _reports.indexWhere((r) => r.id == report.id);
        if (i != -1) {
          if (report.status == 'resolved') {
            _reports.removeAt(i);
          } else {
            _reports[i] = report;
          }
        } else if (report.status != 'resolved') {
          _reports.insert(0, report);
        }
      });
    });
  }

  Future<void> _load() async {
    final reports = await AppServices.fraud.listOpenReports();
    if (!mounted) return;
    setState(() {
      _reports
        ..clear()
        ..addAll(reports);
      _loading = false;
    });
  }

  Future<void> _decide(FraudReport report, String decision) async {
    setState(() => _error = null);
    try {
      await AppServices.fraud.updateDecision(fraudReportId: report.id, adminDecision: decision);
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
        if (_reports.isEmpty)
          const Expanded(child: Center(child: Text('No open fraud reports.')))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _reports.length,
              itemBuilder: (context, i) {
                final r = _reports[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Reported by ${r.reportedByRole} ${r.reportedById}'),
                        if (r.description != null && r.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(r.description!),
                        ],
                        if (r.aiSummary != null) ...[
                          const SizedBox(height: 8),
                          Text('AI summary: ${r.aiSummary}', style: const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                        if (r.aiRecommendation != null) ...[
                          const SizedBox(height: 4),
                          Text('AI recommends: ${r.aiRecommendation}',
                              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: _decisions
                              .map((d) => OutlinedButton(
                                    onPressed: () => _decide(r, d),
                                    child: Text(d),
                                  ))
                              .toList(),
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
