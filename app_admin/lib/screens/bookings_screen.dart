import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

const _terminalStatuses = [
  BookingStatus.completed,
  BookingStatus.cancelled,
  BookingStatus.refunded,
];

/// Plan §12 Admin Panel checklist: "Booking management (full detail + audit history +
/// actions)" + §10.4 dispute resolution (raise a dispute off a non-terminal booking, then
/// resolve it to refunded/completed — both legal `disputed` exits per transitionBooking.js's
/// guard table).
class BookingsBody extends StatefulWidget {
  const BookingsBody({super.key});

  @override
  State<BookingsBody> createState() => _BookingsBodyState();
}

class _BookingsBodyState extends State<BookingsBody> {
  final List<Booking> _bookings = [];
  RealtimeSubscription? _subscription;
  bool _loading = true;
  String? _error;
  String? _adminAuthId;

  @override
  void initState() {
    super.initState();
    _load();
    AppServices.auth.getCurrentUser().then((u) {
      if (mounted) setState(() => _adminAuthId = u?.$id);
    });
    _subscription = AppServices.bookings.subscribeToBookings();
    _subscription!.stream.listen((event) {
      final payload = event.payload;
      final booking = Booking.fromMap(payload);
      setState(() {
        final i = _bookings.indexWhere((b) => b.id == booking.id);
        if (i != -1) {
          _bookings[i] = booking;
        } else {
          _bookings.insert(0, booking);
        }
      });
    });
  }

  Future<void> _load() async {
    final bookings = await AppServices.bookings.listAllBookings();
    if (!mounted) return;
    setState(() {
      _bookings
        ..clear()
        ..addAll(bookings);
      _loading = false;
    });
  }

  Future<void> _transition(
    Booking booking,
    BookingStatus next, {
    String? confirmMessage,
  }) async {
    if (confirmMessage != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(confirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _error = null);
    try {
      await AppServices.bookings.transition(
        bookingId: booking.id,
        nextStatus: next,
        changedByRole: 'admin',
        changedById: _adminAuthId ?? 'admin',
      );
    } catch (e) {
      setState(() => _error = 'Action failed: $e');
    }
  }

  Future<void> _showDetail(Booking b) async {
    final history = await AppServices.bookings.listStatusHistory(b.id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking detail'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  b.problemText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(b.addressText),
                Text('Category: ${b.categoryId}'),
                if (b.finalQuote != null)
                  Text('Quote: Rs. ${b.finalQuote!.toStringAsFixed(0)}'),
                if (b.workSummary != null && b.workSummary!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Work summary: ${b.workSummary}'),
                ],
                const Divider(height: 24),
                Text(
                  'Status history',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  const Text('No history recorded yet.')
                else
                  ...history.map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${h['status']} — ${h['changedByRole']} · ${h['timestamp'] ?? ''}'
                        '${(h['note'] as String?)?.isNotEmpty == true ? '\n  ${h['note']}' : ''}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_bookings.isEmpty) return const Center(child: Text('No bookings yet.'));
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _bookings.length,
            itemBuilder: (context, i) {
              final b = _bookings[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  onTap: () => _showDetail(b),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.problemText),
                        const SizedBox(height: 4),
                        Text('${b.addressText}\n${b.status.wire}'),
                        if (b.finalQuote != null)
                          Text('Rs. ${b.finalQuote!.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (b.status == BookingStatus.disputed) ...[
                              FilledButton(
                                onPressed: () => _transition(
                                  b,
                                  BookingStatus.refunded,
                                  confirmMessage: 'Refund this booking?',
                                ),
                                child: const Text('Refund'),
                              ),
                              OutlinedButton(
                                onPressed: () => _transition(
                                  b,
                                  BookingStatus.completed,
                                  confirmMessage: 'Mark completed (no refund)?',
                                ),
                                child: const Text('Mark completed'),
                              ),
                            ] else if (!_terminalStatuses.contains(b.status))
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                ),
                                onPressed: () => _transition(
                                  b,
                                  BookingStatus.disputed,
                                  confirmMessage:
                                      'Raise a dispute on this booking?',
                                ),
                                child: const Text('Raise dispute'),
                              ),
                          ],
                        ),
                      ],
                    ),
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
