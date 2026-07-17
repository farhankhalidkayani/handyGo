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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Chat-scan flags', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_flaggedMessages.isEmpty)
          const Text('No flagged messages.')
        else
          ..._flaggedMessages.map((m) => Card(
                color: Colors.orange.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.flagReason ?? 'Flagged', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(m.text),
                      const SizedBox(height: 4),
                      Text('Booking ${m.bookingId} · ${m.senderRole}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 24),
        Text('Worker performance flags', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_lowPerformers.isEmpty)
          const Text('No workers currently flagged for low performance.')
        else
          ..._lowPerformers.map((w) => Card(
                color: Colors.red.withValues(alpha: 0.05),
                child: ListTile(
                  title: Text('Performance score: ${w.performanceScore}/100'),
                  subtitle: Text('Rating ${w.rating.toStringAsFixed(1)} · ${w.jobsCompleted} jobs completed'),
                  trailing: const Icon(Icons.trending_down, color: Colors.red),
                ),
              )),
      ],
    );
  }
}
