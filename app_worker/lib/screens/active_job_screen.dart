import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Drives the worker's side of the booking state machine (plan §7): confirmed ->
/// worker_on_the_way -> worker_arrived -> (OTP) service_started -> in_progress ->
/// completion_requested. Full navigation/ETA (§12 "Navigation (OSM/OSRM route)") is a
/// follow-up — this covers the status sequence + OTP gate that make the demo real.
class ActiveJobScreen extends StatefulWidget {
  final UserProfile profile;
  final String bookingId;

  const ActiveJobScreen({super.key, required this.profile, required this.bookingId});

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

const _nextStatusByCurrent = {
  BookingStatus.workerSelected: (BookingStatus.confirmed, 'Confirm job'),
  BookingStatus.confirmed: (BookingStatus.workerOnTheWay, "I'm on the way"),
  BookingStatus.workerOnTheWay: (BookingStatus.workerArrived, "I've arrived"),
  BookingStatus.inProgress: (BookingStatus.completionRequested, 'Mark job as done'),
};

class _ActiveJobScreenState extends State<ActiveJobScreen> {
  Booking? _booking;
  RealtimeSubscription? _subscription;
  final _otpController = TextEditingController();
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

  Future<void> _advance(BookingStatus next) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.bookings.transition(
        bookingId: widget.bookingId,
        nextStatus: next,
        changedByRole: 'worker',
        changedById: widget.profile.id,
      );
    } catch (e) {
      setState(() => _error = 'Could not update status: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.bookings.transition(
        bookingId: widget.bookingId,
        nextStatus: BookingStatus.serviceStarted,
        changedByRole: 'worker',
        changedById: widget.profile.id,
        otp: _otpController.text.trim(),
      );
      await AppServices.bookings.transition(
        bookingId: widget.bookingId,
        nextStatus: BookingStatus.inProgress,
        changedByRole: 'system',
        changedById: widget.profile.id,
      );
    } catch (e) {
      setState(() => _error = 'Invalid OTP: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    if (booking == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (booking.status == BookingStatus.completed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job complete')),
        body: const Center(child: Text('This job is complete.')),
      );
    }

    final next = _nextStatusByCurrent[booking.status];
    final awaitingOtp = booking.status == BookingStatus.workerArrived;

    return Scaffold(
      appBar: AppBar(title: const Text('Active job')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking.status.wire, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(booking.problemText),
            Text(booking.addressText),
            if (booking.finalQuote != null) Text('Quote: Rs. ${booking.finalQuote!.toStringAsFixed(0)}'),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (awaitingOtp) ...[
              const Text('Ask the customer for their 4-digit code to start the service.'),
              const SizedBox(height: 8),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Customer OTP'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submitOtp,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                    : const Text('Start service'),
              ),
            ] else if (next != null)
              FilledButton(
                onPressed: _busy ? null : () => _advance(next.$1),
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                    : Text(next.$2),
              )
            else
              const Text('Waiting for the customer to confirm & pay.'),
          ],
        ),
      ),
    );
  }
}
