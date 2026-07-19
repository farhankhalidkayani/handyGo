import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'home_screen.dart';

class RatingScreen extends StatefulWidget {
  final UserProfile profile;
  final String bookingId;

  const RatingScreen({
    super.key,
    required this.profile,
    required this.bookingId,
  });

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

  static const _ratingLabels = {
    1: 'Poor',
    2: 'Fair',
    3: 'Good',
    4: 'Great',
    5: 'Excellent',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your experience')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.celebration_outlined,
                  size: 32,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'How was your service?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 20),
          if (_invoice != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Invoice',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InvoiceRow(
                    label: 'Service charges',
                    amount: _invoice!.serviceCharges,
                  ),
                  if (_invoice!.materialCharges > 0)
                    _InvoiceRow(
                      label: 'Materials',
                      amount: _invoice!.materialCharges,
                    ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total paid',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Rs. ${_invoice!.total.toStringAsFixed(0)} (${_invoice!.method.toUpperCase()})',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starValue = i + 1;
                  final filled = starValue <= _rating;
                  return IconButton(
                        iconSize: 40,
                        icon: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                        ),
                        onPressed: () => setState(() => _rating = starValue),
                      )
                      .animate(target: filled ? 1 : 0)
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                        duration: 150.ms,
                      );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                _ratingLabels[_rating] ?? '',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _reviewController,
            decoration: const InputDecoration(
              labelText: 'Leave a review (optional)',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: scheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final String label;
  final double amount;

  const _InvoiceRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          Text('Rs. ${amount.toStringAsFixed(0)}'),
        ],
      ),
    );
  }
}
