import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'tracking_screen.dart';

/// Plan §12/§6.2/§9.6: realtime-subscribed offer comparison (InDrive-style). Subscribes to
/// the whole worker_offers channel and filters by bookingId client-side, per the plan's own
/// subscription example — Appwrite Realtime fans out from one write to every listener.
class OffersScreen extends StatefulWidget {
  final UserProfile profile;
  final String bookingId;

  const OffersScreen({super.key, required this.profile, required this.bookingId});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final List<WorkerOffer> _offers = [];
  RealtimeSubscription? _subscription;
  bool _loading = true;
  bool _accepting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = AppServices.offers.subscribeToOffers();
    _subscription!.stream.listen((event) {
      final payload = event.payload;
      if (payload['bookingId'] != widget.bookingId) return;
      if (event.events.any((e) => e.contains('.create'))) {
        setState(() => _offers.add(WorkerOffer.fromMap(payload)));
        _refreshComparison();
      } else if (event.events.any((e) => e.contains('.update'))) {
        setState(() {
          final i = _offers.indexWhere((o) => o.id == payload['\$id']);
          if (i != -1) _offers[i] = WorkerOffer.fromMap(payload);
        });
      }
    });
  }

  String? _bestMatchOfferId;
  String? _topRatedOfferId;

  Future<void> _load() async {
    final offers = await AppServices.offers.listForBooking(widget.bookingId);
    if (!mounted) return;
    setState(() {
      _offers
        ..clear()
        ..addAll(offers);
      _loading = false;
    });
    _refreshComparison();
  }

  Future<void> _refreshComparison() async {
    if (_offers.where((o) => o.status == 'sent').isEmpty) return;
    try {
      final result = await AppServices.offers.compareOffers(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _bestMatchOfferId = result['bestMatchOfferId'] as String?;
        _topRatedOfferId = result['topRatedOfferId'] as String?;
      });
    } catch (_) {
      // best-effort — price/fastest tags still show without this
    }
  }

  Future<void> _accept(WorkerOffer offer) async {
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      await AppServices.bookings.selectOffer(
        bookingId: widget.bookingId,
        offerId: offer.id,
        customerId: widget.profile.id,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TrackingScreen(profile: widget.profile, bookingId: widget.bookingId),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Could not accept offer: $e');
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentOffers = _offers.where((o) => o.status == 'sent').toList();
    final bestPrice = sentOffers.isEmpty
        ? null
        : sentOffers.reduce((a, b) => a.quote < b.quote ? a : b);
    final fastest = sentOffers.isEmpty
        ? null
        : sentOffers.reduce((a, b) => (a.etaMins ?? 1 << 30) < (b.etaMins ?? 1 << 30) ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Compare offers')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (sentOffers.isEmpty)
                  const Expanded(
                    child: Center(child: Text('Waiting for workers to send offers...')),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: sentOffers.length,
                      itemBuilder: (context, i) {
                        final offer = sentOffers[i];
                        final tags = <String>[
                          if (offer == bestPrice) 'Best price',
                          if (offer == fastest) 'Fastest',
                          if (offer.id == _topRatedOfferId) 'Top rated',
                          if (offer.id == _bestMatchOfferId) 'Best match',
                        ];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Rs. ${offer.quote.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                if (offer.etaMins != null) Text('ETA: ${offer.etaMins} mins'),
                                if (offer.message != null && offer.message!.isNotEmpty)
                                  Text(offer.message!),
                                if (offer.flaggedSuspicious)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'This quote looks unusual compared to similar jobs — double-check before accepting.',
                                            style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (tags.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Wrap(
                                      spacing: 6,
                                      children: tags.map((t) => Chip(label: Text(t))).toList(),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _accepting ? null : () => _accept(offer),
                                  child: const Text('Accept'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
