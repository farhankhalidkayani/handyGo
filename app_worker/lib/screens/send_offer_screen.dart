import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §9.8 W2/W3/W4: AI quote suggestion + tools/materials + a draft offer message,
/// pre-filled but always editable — the worker sends whatever they actually decide on.
class SendOfferScreen extends StatefulWidget {
  final UserProfile profile;
  final Booking booking;

  const SendOfferScreen({super.key, required this.profile, required this.booking});

  @override
  State<SendOfferScreen> createState() => _SendOfferScreenState();
}

class _SendOfferScreenState extends State<SendOfferScreen> {
  final _quoteController = TextEditingController();
  final _etaController = TextEditingController(text: '30');
  final _messageController = TextEditingController();
  bool _sending = false;
  bool _loadingSuggestion = true;
  List<String> _suggestedTools = [];
  List<String> _suggestedMaterials = [];
  String? _error;
  int? _customerRiskScore;

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
    _loadCustomerRisk();
  }

  /// Plan §12 "proactive unsafe-customer warning" — `users.riskScore` is actually a trust
  /// score despite its name (scoreEngine.js computes it as 100 minus penalties, so LOW means
  /// risky, not high — see that file's comment), recomputed daily from cancellations/fraud
  /// reports/SOS misuse.
  Future<void> _loadCustomerRisk() async {
    try {
      final customer = await AppServices.profiles.findById(widget.booking.customerId);
      if (mounted) setState(() => _customerRiskScore = customer?.riskScore);
    } catch (_) {
      // best-effort — never block offer creation on this
    }
  }

  Future<void> _loadSuggestion() async {
    try {
      final result = await AppServices.bookings.getWorkerAssist(booking: widget.booking, mode: 'quote');
      if (!mounted) return;
      setState(() {
        _quoteController.text = (result['suggestedQuote'] as num?)?.toStringAsFixed(0) ?? '';
        _messageController.text = result['offerMessage'] as String? ?? '';
        _suggestedTools = (result['tools'] as List?)?.cast<String>() ?? [];
        _suggestedMaterials = (result['materials'] as List?)?.cast<String>() ?? [];
      });
    } catch (_) {
      // AI suggestion is a convenience, not a requirement — worker can still fill in manually
    } finally {
      if (mounted) setState(() => _loadingSuggestion = false);
    }
  }

  Future<void> _send() async {
    final quote = double.tryParse(_quoteController.text.trim());
    if (quote == null || quote <= 0) {
      setState(() => _error = 'Enter a valid quote');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AppServices.offers.createOffer(
        bookingId: widget.booking.id,
        workerId: widget.profile.id,
        quote: quote,
        etaMins: int.tryParse(_etaController.text.trim()),
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not send offer: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _quoteController.dispose();
    _etaController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Send offer')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.booking.problemText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(widget.booking.addressText, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_customerRiskScore != null && _customerRiskScore! < 50) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This customer has a low trust score ($_customerRiskScore/100) from past cancellations or reports — proceed carefully.',
                      style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_loadingSuggestion)
            Row(
              children: [
                SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary)),
                const SizedBox(width: 10),
                Text('Getting AI quote suggestion...', style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          if (_suggestedTools.isNotEmpty || _suggestedMaterials.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 15, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 6),
                      Text('AI suggestions',
                          style: TextStyle(
                              color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                  if (_suggestedTools.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ChipRow(icon: Icons.build_outlined, items: _suggestedTools, scheme: scheme),
                  ],
                  if (_suggestedMaterials.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ChipRow(icon: Icons.inventory_2_outlined, items: _suggestedMaterials, scheme: scheme),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _quoteController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Your quote (Rs.)', prefixIcon: Icon(Icons.payments_outlined)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _etaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'ETA (mins)', prefixIcon: Icon(Icons.schedule)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(labelText: 'Message — AI-drafted, editable'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: scheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_outlined),
            label: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final IconData icon;
  final List<String> items;
  final ColorScheme scheme;

  const _ChipRow({required this.icon, required this.items, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 4),
                    Text(item, style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
