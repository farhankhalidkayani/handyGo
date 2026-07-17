import 'package:flutter/material.dart';

import '../services/app_services.dart';

const _fraudTypes = ['fake_booking', 'no_show', 'harassment', 'payment_issue', 'unsafe_customer', 'other'];

/// Plan §10.4: fraud reporting — non-immediate financial/account issues, distinct from SOS
/// (immediate danger). AI only recommends (`aiSummary`/`aiRecommendation`, filled in
/// server-side by eventRouter's `fraud` handler); admin makes the final `adminDecision`.
class ReportFraudScreen extends StatefulWidget {
  final String reportedById;
  final String? bookingId;
  final String? accusedId;

  const ReportFraudScreen({super.key, required this.reportedById, this.bookingId, this.accusedId});

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
        const SnackBar(content: Text('Report submitted. Our team will review it.')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Report an issue')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: _fraudTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'What happened?'),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                  : const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  }
}
