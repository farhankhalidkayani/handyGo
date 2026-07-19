import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'offers_screen.dart';

/// Plan §12 Customer App checklist: "Service request: manual / AI chatbot / image — all
/// writing to `bookings`". This covers the manual path; AI chatbot/image intake come with
/// the AI layer phases (§13 Phase 4+) — this screen is deliberately category-picker-first so
/// the core booking state machine has something real to drive end to end.
class ServiceRequestScreen extends StatefulWidget {
  final UserProfile profile;
  final String? initialCategoryId;

  const ServiceRequestScreen({super.key, required this.profile, this.initialCategoryId});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemController = TextEditingController();
  final _addressController = TextEditingController();
  late Future<List<ServiceCategory>> _categoriesFuture;
  String? _selectedCategoryId;
  bool _submitting = false;
  String? _error;
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = AppServices.categories.listAll();
    _selectedCategoryId = widget.initialCategoryId;
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      setState(() => _error = 'Select a category');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      double lat = 0;
      double lng = 0;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (_) {
        // fall back to (0,0) — recommendWorkers/routePlanner will still run, just with a
        // meaningless distance; good enough for this pass without full address geocoding.
      }

      final booking = await AppServices.bookings.createBooking(
        customerId: widget.profile.id,
        categoryId: _selectedCategoryId!,
        problemText: _problemController.text.trim(),
        addressText: _addressController.text.trim(),
        lat: lat,
        lng: lng,
        scheduledAt: _scheduledAt,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OffersScreen(profile: widget.profile, bookingId: booking.id)),
      );
    } catch (e) {
      setState(() => _error = 'Could not create booking: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _problemController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Request a service')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              FutureBuilder<List<ServiceCategory>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                    items: snapshot.data!
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _problemController,
                decoration: const InputDecoration(labelText: 'Describe the problem'),
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickSchedule,
                icon: const Icon(Icons.schedule_outlined),
                label: Text(_scheduledAt == null
                    ? 'Book now (tap to schedule for later instead)'
                    : 'Scheduled: ${_scheduledAt!.toLocal()}'.split('.').first),
              ),
              if (_scheduledAt != null)
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _scheduledAt = null),
                    child: const Text('Cancel scheduling — book now instead'),
                  ),
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
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search),
                label: const Text('Find workers'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
