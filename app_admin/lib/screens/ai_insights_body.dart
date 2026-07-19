import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §12 Admin Panel checklist: "AI insights: fraud flags, chat-scan flags, risk/
/// performance scores, demand forecast, revenue, shortage, cancellation reasons — each as
/// recommendation cards". Demand/revenue/shortage/cancellation reasons live on the Analytics
/// tab (raw numbers); fraud flags + risk level already have dedicated Fraud/SOS tabs with
/// their own decision buttons. This tab covers what's genuinely new: chat-scan flags and
/// worker performance scores, each shown as a recommendation card (a nudge, not an auto-action
/// — §8.3 governance rule).
class AiInsightsBody extends StatefulWidget {
  const AiInsightsBody({super.key});

  @override
  State<AiInsightsBody> createState() => _AiInsightsBodyState();
}

class _AiInsightsBodyState extends State<AiInsightsBody> {
  List<Message> _flaggedMessages = [];
  List<WorkerProfile> _lowPerformers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final flagged = await AppServices.messages.listFlagged();
      final workersRes = await AppServices.databases.listDocuments(
        databaseId: HandyGoConfig.databaseId,
        collectionId: Collections.workerProfiles,
        queries: [Query.limit(200)],
      );
      final workers = workersRes.documents
          .map((d) => WorkerProfile.fromMap({...d.data, '\$id': d.$id}))
          .where((w) => w.performanceScore < 60)
          .toList()
        ..sort((a, b) => a.performanceScore.compareTo(b.performanceScore));
      if (!mounted) return;
      setState(() {
        _flaggedMessages = flagged;
        _lowPerformers = workers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load insights: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: scheme.error)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.forum_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('Chat-scan flags', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        if (_flaggedMessages.isEmpty)
          Text('No flagged messages.', style: TextStyle(color: scheme.onSurfaceVariant))
        else
          ..._flaggedMessages.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: Colors.orange, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 15, color: Colors.orange.shade800),
                        const SizedBox(width: 6),
                        Text(m.flagReason ?? 'Flagged',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(m.text),
                    const SizedBox(height: 4),
                    Text('Booking ${m.bookingId} · ${m.senderRole}',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              )),
        const SizedBox(height: 28),
        Row(
          children: [
            Icon(Icons.trending_down, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('Worker performance flags', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        if (_lowPerformers.isEmpty)
          Text('No workers currently flagged for low performance.',
              style: TextStyle(color: scheme.onSurfaceVariant))
        else
          ..._lowPerformers.map((w) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: Colors.red.shade300, width: 4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Performance score: ${w.performanceScore}/100',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('Rating ${w.rating.toStringAsFixed(1)} · ${w.jobsCompleted} jobs completed',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.trending_down, color: Colors.red),
                  ],
                ),
              )),
      ],
    );
  }
}
