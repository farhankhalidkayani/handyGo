import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_services.dart';

/// Plan §9.6 C5: "Recommend nearby verified workers" — informational only, shown alongside
/// the offer/bid flow (C6, already built in offers_screen.dart), not a replacement for it.
/// No worker names are shown (they haven't offered on this job, let alone been accepted) —
/// just rating/ETA/distance, consistent with not exposing identity before any commitment.
class NearbyWorkersScreen extends StatefulWidget {
  final String? bookingId;
  final String categoryName;
  final double lat;
  final double lng;

  const NearbyWorkersScreen({
    super.key,
    this.bookingId,
    required this.categoryName,
    required this.lat,
    required this.lng,
  });

  @override
  State<NearbyWorkersScreen> createState() => _NearbyWorkersScreenState();
}

class _NearbyWorkersScreenState extends State<NearbyWorkersScreen> {
  List<Map<String, dynamic>> _candidates = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // No realtime channel exists for this aggregated AI-router call (worker locations move
    // continuously) — poll periodically so distances/ETAs don't go stale while this is open.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await AppServices.bookings.getNearbyWorkers(
        bookingId: widget.bookingId,
        categoryName: widget.categoryName,
        lat: widget.lat,
        lng: widget.lng,
      );
      if (!mounted) return;
      setState(() {
        _candidates =
            (result['candidates'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load nearby workers: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby workers')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            )
          : _candidates.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_search_outlined,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No verified workers with this skill are online nearby right now — '
                      'workers can still send you an offer once they come online.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _candidates.length,
                itemBuilder: (context, i) {
                  final c = _candidates[i];
                  final isBest = c['isBestMatch'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isBest
                          ? scheme.primaryContainer.withValues(alpha: 0.4)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: isBest
                          ? Border.all(
                              color: scheme.primary.withValues(alpha: 0.4),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: scheme.secondaryContainer,
                          child: Icon(
                            Icons.person_outline,
                            color: scheme.onSecondaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    (c['rating'] as num).toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    ' · ${c['jobsCompleted']} jobs completed',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(c['dist'] as num).toStringAsFixed(1)} km away · ETA ~${c['etaMins']} mins',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isBest)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Best match',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
