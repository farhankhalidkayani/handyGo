import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §8.3/A7: "Demand forecast, revenue analysis, worker-shortage, cancellation reasons".
/// Reads `analytics_daily` (populated by eventRouter's scheduled scoreEngine+analyticsRollup
/// job, §9.10) — the narrative/forecast layer on top of these numbers is a follow-up; this is
/// the rules-based aggregation the plan explicitly separates from the LLM narrative (§9.1/A7).
class AnalyticsBody extends StatefulWidget {
  const AnalyticsBody({super.key});

  @override
  State<AnalyticsBody> createState() => _AnalyticsBodyState();
}

class _AnalyticsBodyState extends State<AnalyticsBody> {
  Map<String, dynamic>? _latest;
  Map<String, String> _categoryNames = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await AppServices.categories.listAll();
      final res = await AppServices.databases.listDocuments(
        databaseId: HandyGoConfig.databaseId,
        collectionId: Collections.analyticsDaily,
        queries: [Query.orderDesc('date'), Query.limit(1)],
      );
      if (!mounted) return;
      setState(() {
        _categoryNames = {for (final c in categories) c.id: c.name};
        _latest = res.documents.isNotEmpty ? res.documents.first.data : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load analytics: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    final latest = _latest;
    if (latest == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No analytics yet — the scoreEngine + analyticsRollup job runs once daily. '
            'Run it manually via node functions/... or wait for the next scheduled run.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final demandByCategory = Map<String, dynamic>.from(jsonDecode(latest['demandByCategory'] as String? ?? '{}'));
    final cancellationReasons =
        Map<String, dynamic>.from(jsonDecode(latest['cancellationReasons'] as String? ?? '{}'));
    final maxDemand = demandByCategory.values.cast<int>().fold<int>(0, (max, v) => v > max ? v : max);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Today (${(latest['date'] as String).split('T').first})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(label: 'Bookings', value: '${latest['totalBookings']}'),
            _StatCard(label: 'Completed', value: '${latest['completed']}'),
            _StatCard(label: 'Cancelled', value: '${latest['cancelled']}'),
            _StatCard(label: 'Revenue', value: 'Rs. ${latest['revenue']}'),
            _StatCard(label: 'Avg rating', value: (latest['avgRating'] as num).toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 24),
        Text('Demand by category', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (demandByCategory.isEmpty)
          const Text('No bookings recorded today.')
        else
          ...demandByCategory.entries.map((e) {
            final name = _categoryNames[e.key] ?? e.key;
            final count = e.value as int;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 120, child: Text(name)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: maxDemand == 0 ? 0 : count / maxDemand,
                      minHeight: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$count'),
                ],
              ),
            );
          }),
        const SizedBox(height: 24),
        Text('Cancellation reasons', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (cancellationReasons.isEmpty)
          const Text('No cancellations recorded today.')
        else
          ...cancellationReasons.entries.map((e) => Text('${e.key}: ${e.value}')),
        const SizedBox(height: 24),
        Text('Worker-shortage areas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Not yet implemented server-side — needs geographic clustering of demand vs. '
          'online worker coverage (see analyticsRollup.js).',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
