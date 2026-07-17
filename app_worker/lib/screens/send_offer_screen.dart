import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Send offer')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Text(widget.booking.problemText),
            Text(widget.booking.addressText, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            if (_loadingSuggestion)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Getting AI quote suggestion...'),
                  ],
                ),
              ),
            if (_suggestedTools.isNotEmpty || _suggestedMaterials.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_suggestedTools.isNotEmpty) Text('Suggested tools: ${_suggestedTools.join(', ')}'),
                    if (_suggestedMaterials.isNotEmpty)
                      Text('Suggested materials: ${_suggestedMaterials.join(', ')}'),
                  ],
                ),
              ),
            TextField(
              controller: _quoteController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Your quote (Rs.) — AI-suggested, editable'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _etaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ETA (mins)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Message — AI-drafted, editable'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                  : const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
