import 'package:flutter/material.dart';

import '../services/app_services.dart';

const _fraudTypes = [
  'fake_booking',
  'no_show',
  'harassment',
  'payment_issue',
  'unsafe_customer',
  'other',
];

const _fraudTypeIcons = {
  'fake_booking': Icons.report_gmailerrorred_outlined,
  'overcharge': Icons.price_change_outlined,
  'no_show': Icons.event_busy_outlined,
  'damage': Icons.broken_image_outlined,
  'harassment': Icons.sentiment_very_dissatisfied_outlined,
  'payment_issue': Icons.payments_outlined,
  'unsafe_customer': Icons.warning_amber_outlined,
  'other': Icons.more_horiz,
};

String _fraudTypeLabel(String t) =>
    t.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

/// Plan §10.4: fraud reporting — non-immediate financial/account issues, distinct from SOS
/// (immediate danger). AI only recommends (`aiSummary`/`aiRecommendation`, filled in
/// server-side by eventRouter's `fraud` handler); admin makes the final `adminDecision`.
class ReportFraudScreen extends StatefulWidget {
  final String reportedById;
  final String? bookingId;
  final String? accusedId;

  const ReportFraudScreen({
    super.key,
    required this.reportedById,
    this.bookingId,
    this.accusedId,
  });

  @override
  State<ReportFraudScreen> createState() => _ReportFraudScreenState();
}

class _ReportFraudScreenState extends State<ReportFraudScreen> {
  String _type = _fraudTypes.first;
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _error = 'Please describe what happened');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AppServices.fraud.fileReport(
        reportedByRole: 'worker',
        reportedById: widget.reportedById,
        type: _type,
        bookingId: widget.bookingId,
        accusedId: widget.accusedId,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Our team will review it.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not submit report: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Report an issue')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'What kind of issue?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _fraudTypes.map((t) {
              final selected = t == _type;
              return ChoiceChip(
                avatar: Icon(
                  _fraudTypeIcons[t] ?? Icons.flag_outlined,
                  size: 16,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
                label: Text(_fraudTypeLabel(t)),
                selected: selected,
                selectedColor: scheme.primary,
                labelStyle: TextStyle(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'What happened?'),
            maxLines: 4,
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
                : const Icon(Icons.send_outlined),
            label: const Text('Submit report'),
          ),
        ],
      ),
    );
  }
}
