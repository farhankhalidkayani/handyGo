import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §12 Admin Panel checklist: "Booking management (full detail + audit history +
/// actions)". This is the read-only live list — full detail/audit-history/actions (cancel,
/// force-refund, etc.) are a follow-up; this proves realtime sync across all 3 apps from the
/// admin side (§6.1: Admin subscribes to ALL collections).
class BookingsBody extends StatefulWidget {
  const BookingsBody({super.key});

  @override
  State<BookingsBody> createState() => _BookingsBodyState();
}

class _BookingsBodyState extends State<BookingsBody> {
  final List<Booking> _bookings = [];
  RealtimeSubscription? _subscription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_bookings.isEmpty) return const Center(child: Text('No bookings yet.'));
    return ListView.builder(
      itemCount: _bookings.length,
      itemBuilder: (context, i) {
        final b = _bookings[i];
        return ListTile(
          title: Text(b.problemText),
          subtitle: Text('${b.addressText}\n${b.status.wire}'),
          isThreeLine: true,
          trailing: b.finalQuote != null ? Text('Rs. ${b.finalQuote!.toStringAsFixed(0)}') : null,
        );
      },
    );
  }
}
