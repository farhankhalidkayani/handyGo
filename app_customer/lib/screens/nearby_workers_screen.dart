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

  @override
  void initState() {
    super.initState();
    _load();
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
        _candidates = (result['candidates'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load nearby workers: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby workers')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _candidates.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No verified workers with this skill are online nearby right now — '
                          'workers can still send you an offer once they come online.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _candidates.length,
                      itemBuilder: (context, i) {
                        final c = _candidates[i];
                        final isBest = c['isBestMatch'] == true;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text('Rating ${(c['rating'] as num).toStringAsFixed(1)}'
                                ' · ${c['jobsCompleted']} jobs completed'),
                            subtitle: Text(
                              '${(c['dist'] as num).toStringAsFixed(1)} km away · ETA ~${c['etaMins']} mins',
                            ),
                            trailing: isBest ? const Chip(label: Text('Best match')) : null,
                          ),
                        );
                      },
                    ),
    );
  }
}
