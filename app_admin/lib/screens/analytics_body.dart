import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

const _statCardMeta = {
  'Bookings': Icons.calendar_today_outlined,
  'Completed': Icons.check_circle_outline,
  'Cancelled': Icons.cancel_outlined,
  'Revenue': Icons.payments_outlined,
  'Avg rating': Icons.star_outline,
};

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
  List<Map<String, dynamic>> _recentDays = [];
  Map<String, String> _categoryNames = {};
  bool _loading = true;
  String? _error;
  RealtimeSubscription? _analyticsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _analyticsSub = AppServices.realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.analyticsDaily}.documents',
    ]);
    _analyticsSub!.stream.listen((_) => _load());
  }

  @override
  void dispose() {
    _analyticsSub?.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final categories = await AppServices.categories.listAll();
      final res = await AppServices.databases.listDocuments(
        databaseId: HandyGoConfig.databaseId,
        collectionId: Collections.analyticsDaily,
        queries: [Query.orderDesc('date'), Query.limit(14)],
      );
      if (!mounted) return;
      final days = res.documents.map((d) => d.data).toList();
      setState(() {
        _categoryNames = {for (final c in categories) c.id: c.name};
        _latest = days.isNotEmpty ? days.first : null;
        _recentDays = days.reversed
            .toList(); // oldest -> newest, left-to-right on the chart
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
    if (_error != null)
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
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

    final demandByCategory = Map<String, dynamic>.from(
      jsonDecode(latest['demandByCategory'] as String? ?? '{}'),
    );
    final cancellationReasons = Map<String, dynamic>.from(
      jsonDecode(latest['cancellationReasons'] as String? ?? '{}'),
    );
    final maxDemand = demandByCategory.values.cast<int>().fold<int>(
      0,
      (max, v) => v > max ? v : max,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Today (${(latest['date'] as String).split('T').first})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(label: 'Bookings', value: '${latest['totalBookings']}'),
              _StatCard(label: 'Completed', value: '${latest['completed']}'),
              _StatCard(label: 'Cancelled', value: '${latest['cancelled']}'),
              _StatCard(label: 'Revenue', value: 'Rs. ${latest['revenue']}'),
              _StatCard(
                label: 'Avg rating',
                value: (latest['avgRating'] as num).toStringAsFixed(1),
              ),
            ],
          ),
          if ((latest['aiNarrative'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      latest['aiNarrative'] as String,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
          ],
          if (_recentDays.length > 1) ...[
            const SizedBox(height: 24),
            Text(
              'Revenue (last ${_recentDays.length} days)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _TrendChart(
              values: _recentDays
                  .map((d) => (d['revenue'] as num?)?.toDouble() ?? 0)
                  .toList(),
              color: Colors.green,
              valueFormatter: (v) => 'Rs. ${v.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 24),
            Text(
              'Cancellation rate (last ${_recentDays.length} days)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _TrendChart(
              values: _recentDays.map((d) {
                final total = (d['totalBookings'] as num?)?.toInt() ?? 0;
                final cancelled = (d['cancelled'] as num?)?.toInt() ?? 0;
                return total == 0 ? 0.0 : cancelled / total * 100;
              }).toList(),
              color: Colors.red,
              valueFormatter: (v) => '${v.toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 24),
            Text(
              'Daily bookings (last ${_recentDays.length} days)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'True customer-growth (unique new customers) isn\'t tracked separately — this is '
              'total bookings per day as the closest available proxy.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _TrendChart(
              values: _recentDays
                  .map((d) => (d['totalBookings'] as num?)?.toDouble() ?? 0)
                  .toList(),
              color: Colors.blue,
              valueFormatter: (v) => v.toStringAsFixed(0),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Demand by category',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (demandByCategory.isEmpty)
            Text(
              'No bookings recorded today.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: demandByCategory.entries.map((e) {
                  final name = _categoryNames[e.key] ?? e.key;
                  final count = e.value as int;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: maxDemand == 0 ? 0 : count / maxDemand,
                              minHeight: 10,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$count',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Cancellation reasons',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (cancellationReasons.isEmpty)
            Text(
              'No cancellations recorded today.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cancellationReasons.entries
                  .map(
                    (e) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 24),
          Text(
            'Worker-shortage areas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final shortageAreas = Map<String, dynamic>.from(
                jsonDecode(latest['workerShortageAreas'] as String? ?? '{}'),
              );
              if (shortageAreas.isEmpty) {
                return Text(
                  'No shortage areas detected today.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: shortageAreas.values.map((raw) {
                  final area = Map<String, dynamic>.from(raw as Map);
                  final lat = (area['lat'] as num).toStringAsFixed(2);
                  final lng = (area['lng'] as num).toStringAsFixed(2);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade800,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '~$lat, $lng — ${area['demand']} booking(s), no online workers nearby',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statCardMeta[label] ?? Icons.info_outline,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Deliberately no charting package — a handful of bars is all these trends need, and it
/// keeps this project's dependency footprint small.
class _TrendChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final String Function(double) valueFormatter;

  const _TrendChart({
    required this.values,
    required this.color,
    required this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (max, v) => v > max ? v : max);
    return Container(
      height: 96,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          final heightFraction = maxValue == 0 ? 0.0 : v / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: valueFormatter(v),
                child: FractionallySizedBox(
                  heightFactor: heightFraction.clamp(0.02, 1.0),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.9),
                          color.withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
