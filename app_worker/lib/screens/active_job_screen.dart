import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import '../widgets/sos_button.dart';
import 'chat_screen.dart';
import 'report_fraud_screen.dart';

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

  /// Plan §9.8 W6: post-job work summary, generated from job notes + materials before
  /// transitioning to completion_requested (workSummary is server-only, set only via this
  /// transition — see transitionBooking.js).
  Future<void> _markJobDone() async {
    final notesController = TextEditingController();
    final materialsController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark job as done'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Job notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: materialsController,
              decoration: const InputDecoration(labelText: 'Materials used (comma-separated)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Done')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final materials = materialsController.text
          .split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();
      String? workSummary;
      try {
        final result = await AppServices.bookings.getWorkerAssist(
          booking: _booking!,
          mode: 'summary',
          jobNotes: notesController.text.trim(),
          materials: materials,
        );
        workSummary = result['summary'] as String?;
      } catch (_) {
        // summary is a nice-to-have — never block completion on it
      }

      await AppServices.bookings.transition(
        bookingId: widget.bookingId,
        nextStatus: BookingStatus.completionRequested,
        changedByRole: 'worker',
        changedById: widget.profile.id,
        workSummary: workSummary,
      );
    } catch (e) {
      setState(() => _error = 'Could not mark job done: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Plan §14.2 demo script: worker requests extra payment for unplanned materials mid-job.
  Future<void> _requestAdditionalCharge() async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request additional charge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (Rs.)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason (e.g. extra pipe fitting)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Request')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.bookings.requestAdditionalCharge(
        bookingId: widget.bookingId,
        workerId: widget.profile.id,
        amount: amount,
        reason: reasonController.text.trim(),
      );
    } catch (e) {
      setState(() => _error = 'Could not request additional charge: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this job?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.bookings.transition(
        bookingId: widget.bookingId,
        nextStatus: BookingStatus.cancelled,
        changedByRole: 'worker',
        changedById: widget.profile.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not cancel: $e');
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
      appBar: AppBar(
        title: const Text('Active job'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  bookingId: widget.bookingId,
                  senderId: widget.profile.id,
                  senderRole: 'worker',
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
                  accusedId: booking.customerId,
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
                onPressed: _busy
                    ? null
                    : () => next.$1 == BookingStatus.completionRequested ? _markJobDone() : _advance(next.$1),
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                    : Text(next.$2),
              )
            else
              const Text('Waiting for the customer to confirm & pay.'),
            if (booking.status == BookingStatus.inProgress) ...[
              const SizedBox(height: 16),
              if ((booking.pendingAdditionalCharge ?? 0) > 0)
                Text(
                  'Waiting for customer to approve Rs. ${booking.pendingAdditionalCharge!.toStringAsFixed(0)} '
                  '(${booking.pendingAdditionalChargeReason ?? ''})',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                )
              else
                OutlinedButton(
                  onPressed: _busy ? null : _requestAdditionalCharge,
                  child: const Text('Request additional charge'),
                ),
            ],
            if (![BookingStatus.serviceStarted, BookingStatus.inProgress, BookingStatus.completionRequested]
                .contains(booking.status)) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _busy ? null : _cancelBooking,
                child: const Text('Cancel booking'),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: SosButton(
        raisedByRole: 'worker',
        raisedById: widget.profile.id,
        bookingId: widget.bookingId,
        counterpartId: booking.customerId,
      ),
    );
  }
}
