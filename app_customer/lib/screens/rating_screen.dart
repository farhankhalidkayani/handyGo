import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'home_screen.dart';

class RatingScreen extends StatefulWidget {
  final UserProfile profile;
  final String bookingId;

  const RatingScreen({super.key, required this.profile, required this.bookingId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 5;
  final _reviewController = TextEditingController();
  bool _submitting = false;
  String? _error;
  BookingTransaction? _invoice;

  @override
  void initState() {
    super.initState();
    AppServices.transactions.findForBooking(widget.bookingId).then((t) {
      if (mounted) setState(() => _invoice = t);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AppServices.bookings.submitRating(
        bookingId: widget.bookingId,
        customerId: widget.profile.id,
        rating: _rating,
        reviewText: _reviewController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(profile: widget.profile)),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = 'Could not submit rating: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your experience')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_invoice != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invoice', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Service charges: Rs. ${_invoice!.serviceCharges.toStringAsFixed(0)}'),
                      if (_invoice!.materialCharges > 0)
                        Text('Materials: Rs. ${_invoice!.materialCharges.toStringAsFixed(0)}'),
                      const Divider(),
                      Text('Total paid: Rs. ${_invoice!.total.toStringAsFixed(0)} (${_invoice!.method.toUpperCase()})',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starValue = i + 1;
                return IconButton(
                  iconSize: 36,
                  icon: Icon(
                    starValue <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _rating = starValue),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewController,
              decoration: const InputDecoration(labelText: 'Leave a review (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
