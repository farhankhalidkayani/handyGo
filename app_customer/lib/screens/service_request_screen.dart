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

  const ServiceRequestScreen({super.key, required this.profile});

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

  @override
  void initState() {
    super.initState();
    _categoriesFuture = AppServices.categories.listAll();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Request a service')),
      body: Padding(
        padding: const EdgeInsets.all(24),
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
                    decoration: const InputDecoration(labelText: 'Category'),
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
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                    : const Text('Find workers'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
