import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'chat_screen.dart';
import 'nearby_workers_screen.dart';
import 'tracking_screen.dart';

/// Plan §12/§6.2/§9.6: realtime-subscribed offer comparison (InDrive-style). Subscribes to
/// the whole worker_offers channel and filters by bookingId client-side, per the plan's own
/// subscription example — Appwrite Realtime fans out from one write to every listener.
class OffersScreen extends StatefulWidget {
  final UserProfile profile;
  final String bookingId;

  const OffersScreen({
    super.key,
    required this.profile,
    required this.bookingId,
  });

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
  Booking? _booking;
  String? _categoryName;

  Future<void> _load() async {
    try {
      final offers = await AppServices.offers.listForBooking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _offers
          ..clear()
          ..addAll(offers);
        _loading = false;
        _error = null;
      });
      _refreshComparison();
      _loadBookingCategory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load offers: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadBookingCategory() async {
    try {
      final booking = await AppServices.bookings.getBooking(widget.bookingId);
      final categories = await AppServices.categories.listAll();
      ServiceCategory? category;
      for (final c in categories) {
        if (c.id == booking.categoryId) {
          category = c;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _categoryName = category?.name;
      });
    } catch (_) {
      // "nearby workers" button just won't show — never block the offers screen on this
    }
  }

  /// Plan's "ask a question before offering" — each worker who has messaged gets their own
  /// private thread (message_repository.dart's threadWorkerId), so this shows a picker rather
  /// than jumping straight into one unattributed shared chat.
  Future<void> _openQuestions() async {
    List<String> workerIds;
    try {
      workerIds = await AppServices.messages.listPreOfferThreadWorkerIds(
        widget.bookingId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load questions: $e');
      return;
    }
    if (!mounted) return;
    if (workerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workers have asked a question yet.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: workerIds
              .map(
                (workerId) => ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Worker question'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          bookingId: widget.bookingId,
                          senderId: widget.profile.id,
                          senderRole: 'customer',
                          threadWorkerId: workerId,
                        ),
                      ),
                    );
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _openNearbyWorkers() {
    final booking = _booking;
    final categoryName = _categoryName;
    if (booking == null || categoryName == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NearbyWorkersScreen(
          bookingId: booking.id,
          categoryName: categoryName,
          lat: booking.lat,
          lng: booking.lng,
        ),
      ),
    );
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
          builder: (_) => TrackingScreen(
            profile: widget.profile,
            bookingId: widget.bookingId,
          ),
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
    final scheme = Theme.of(context).colorScheme;
    final sentOffers = _offers.where((o) => o.status == 'sent').toList();
    final bestPrice = sentOffers.isEmpty
        ? null
        : sentOffers.reduce((a, b) => a.quote < b.quote ? a : b);
    final fastest = sentOffers.isEmpty
        ? null
        : sentOffers.reduce(
            (a, b) => (a.etaMins ?? 1 << 30) < (b.etaMins ?? 1 << 30) ? a : b,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare offers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.question_answer_outlined),
            tooltip: 'Questions from workers',
            onPressed: _openQuestions,
          ),
          if (_categoryName != null)
            IconButton(
              icon: const Icon(Icons.travel_explore_outlined),
              tooltip: 'See nearby workers',
              onPressed: _openNearbyWorkers,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              _error!,
                              style: TextStyle(color: scheme.error),
                            ),
                          ),
                        ),
                      ],
                    )
                  : sentOffers.isEmpty
                  ? CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  size: 40,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Waiting for workers to send offers...',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sentOffers.length,
                      itemBuilder: (context, i) {
                        final offer = sentOffers[i];
                        final tags = <(String, IconData)>[
                          if (offer == bestPrice)
                            ('Best price', Icons.savings_outlined),
                          if (offer == fastest)
                            ('Fastest', Icons.bolt_outlined),
                          if (offer.id == _topRatedOfferId)
                            ('Top rated', Icons.star_outline),
                          if (offer.id == _bestMatchOfferId)
                            ('Best match', Icons.auto_awesome),
                        ];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Rs. ${offer.quote.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 22,
                                            ),
                                          ),
                                          if (offer.etaMins != null)
                                            Text(
                                              'ETA: ${offer.etaMins} mins',
                                              style: TextStyle(
                                                color: scheme.onSurfaceVariant,
                                                fontSize: 13,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                        ),
                                        onPressed: _accepting
                                            ? null
                                            : () => _accept(offer),
                                        child: const Text('Accept'),
                                      ),
                                    ),
                                  ],
                                ),
                                if (offer.message != null &&
                                    offer.message!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    offer.message!,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (offer.flaggedSuspicious) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'This quote looks unusual — double-check before accepting.',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (tags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    tags.map((t) => t.$1).join(' · '),
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
