import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import '../widgets/sos_button.dart';
import 'chat_screen.dart';
import 'rating_screen.dart';
import 'report_fraud_screen.dart';

const _statusLabels = {
  BookingStatus.workerSelected: 'Worker selected — waiting for confirmation',
  BookingStatus.confirmed: 'Worker confirmed the job',
  BookingStatus.workerOnTheWay: 'Worker is on the way',
  BookingStatus.workerArrived: 'Worker has arrived',
  BookingStatus.serviceStarted: 'Service started',
  BookingStatus.inProgress: 'Service in progress',
  BookingStatus.completionRequested: 'Worker marked the job as done',
  BookingStatus.paymentPending: 'Confirming payment...',
  BookingStatus.completed: 'Completed',
  BookingStatus.cancelled: 'Cancelled',
  BookingStatus.disputed: 'Disputed',
};

/// Full map/ETA/chat/call/SOS tracking UI (plan §12) is a larger follow-up — this screen
/// covers the part that proves the state machine + realtime sync work end-to-end: live
/// status, the OTP the worker needs to start service, and completion/payment.
class TrackingScreen extends StatefulWidget {
  final UserProfile profile;
  final String bookingId;

  const TrackingScreen({super.key, required this.profile, required this.bookingId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Booking? _booking;
  RealtimeSubscription? _subscription;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = AppServices.bookings.subscribeToBookings();
    _subscription!.stream.listen((event) {
      final payload = event.payload;
      if (payload['\$id'] != widget.bookingId) return;
      setState(() => _booking = Booking.fromMap(payload));
    });
  }

  Future<void> _load() async {
    final booking = await AppServices.bookings.getBooking(widget.bookingId);
    if (!mounted) return;
    setState(() => _booking = booking);
  }

  Future<void> _confirmAndPay() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.bookings.transition(
        bookingId: widget.bookingId,
        nextStatus: BookingStatus.paymentPending,
        changedByRole: 'customer',
        changedById: widget.profile.id,
      );
      await AppServices.bookings.transition(
        bookingId: widget.bookingId,
        nextStatus: BookingStatus.completed,
        changedByRole: 'system',
        changedById: widget.profile.id,
        note: 'COD settled — real payment gateway is out of scope for this build',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RatingScreen(profile: widget.profile, bookingId: widget.bookingId),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Could not complete payment: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    if (booking == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  bookingId: widget.bookingId,
                  senderId: widget.profile.id,
                  senderRole: 'customer',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report an issue',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReportFraudScreen(
                  reportedById: widget.profile.id,
                  bookingId: widget.bookingId,
                  accusedId: booking.workerId,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _statusLabels[booking.status] ?? booking.status.wire,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (booking.otp != null) ...[
              const Text('Share this code with the worker to start the service:'),
              const SizedBox(height: 8),
              Text(booking.otp!, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 16),
            ],
            if (booking.finalQuote != null) Text('Quote: Rs. ${booking.finalQuote!.toStringAsFixed(0)}'),
            const Spacer(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (booking.status == BookingStatus.completionRequested)
              FilledButton(
                onPressed: _busy ? null : _confirmAndPay,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                    : const Text('Confirm & pay (COD)'),
              ),
          ],
        ),
      ),
      floatingActionButton: SosButton(
        raisedByRole: 'customer',
        raisedById: widget.profile.id,
        bookingId: widget.bookingId,
        counterpartId: booking.workerId,
      ),
    );
  }
}
