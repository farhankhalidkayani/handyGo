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

const _decisionIcons = {
  'dismissed': Icons.close,
  'warning': Icons.warning_amber_outlined,
  'refund': Icons.currency_exchange,
  'suspension': Icons.pause_circle_outline,
  'ban': Icons.block,
};

Color _decisionColor(String d) {
  switch (d) {
    case 'suspension':
    case 'ban':
      return Colors.red;
    case 'warning':
      return Colors.orange;
    case 'refund':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}

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
      await AppServices.fraud.updateDecision(
        fraudReportId: report.id,
        adminDecision: decision,
      );
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
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: TextStyle(color: scheme.error)),
          ),
        if (_reports.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.gpp_good_outlined,
                    size: 40,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No open fraud reports.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reports.length,
                itemBuilder: (context, i) {
                  final r = _reports[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                r.type.toUpperCase(),
                                style: TextStyle(
                                  color: scheme.onErrorContainer,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reported by ${r.reportedByRole} ${r.reportedById}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        if (r.description != null &&
                            r.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(r.description!),
                        ],
                        if (r.aiSummary != null ||
                            r.aiRecommendation != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (r.aiSummary != null)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 14,
                                        color: scheme.onPrimaryContainer,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          r.aiSummary!,
                                          style: TextStyle(
                                            color: scheme.onPrimaryContainer,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (r.aiRecommendation != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Recommends: ${r.aiRecommendation}',
                                    style: TextStyle(
                                      color: scheme.onPrimaryContainer,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _decisions
                              .map(
                                (d) => OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _decisionColor(d),
                                  ),
                                  onPressed: () => _decide(r, d),
                                  icon: Icon(
                                    _decisionIcons[d] ?? Icons.check,
                                    size: 16,
                                  ),
                                  label: Text(d),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
