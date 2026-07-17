import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'under_review_screen.dart';

/// Plan §12 Worker App checklist: "Registration (CNIC, selfie, skills, area, docs) →
/// under-review state". Document upload (CNIC/selfie) needs Storage wiring and is left as a
/// follow-up — this covers the fields that gate matching (skills, service area) so
/// `recommendWorkers` has real data to query against.
class WorkerRegistrationScreen extends StatefulWidget {
  final String authId;
  final String email;
  final String language;

  const WorkerRegistrationScreen({
    super.key,
    required this.authId,
    required this.email,
    required this.language,
  });

  @override
  State<WorkerRegistrationScreen> createState() => _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _experienceController = TextEditingController(text: '0');
  late Future<List<ServiceCategory>> _categoriesFuture;
  final Set<String> _selectedSkills = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = AppServices.categories.listAll();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkills.isEmpty) {
      setState(() => _error = 'Select at least one skill');
      return;
    }
    setState(() {
      _saving = true;
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
        // service area defaults to (0,0) if location is unavailable; worker can update later
      }

      final userDoc = await AppServices.profiles.createUserDocument(
        authId: widget.authId,
        role: 'worker',
        name: _nameController.text.trim(),
        email: widget.email,
        phone: _phoneController.text.trim(),
        language: widget.language,
      );
      await AppServices.profiles.createWorkerProfile(
        authId: widget.authId,
        userId: userDoc.$id,
        skills: _selectedSkills.toList(),
        serviceAreaLat: lat,
        serviceAreaLng: lng,
        experienceYears: int.tryParse(_experienceController.text.trim()) ?? 0,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UnderReviewScreen(status: 'under_review')),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = 'Could not save registration: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker registration')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone (e.g. +923001234567)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _experienceController,
                decoration: const InputDecoration(labelText: 'Years of experience'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text('Skills', style: TextStyle(fontWeight: FontWeight.bold)),
              FutureBuilder<List<ServiceCategory>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    children: snapshot.data!.map((c) {
                      final selected = _selectedSkills.contains(c.name);
                      return FilterChip(
                        label: Text(c.name),
                        selected: selected,
                        onSelected: (v) => setState(() {
                          v ? _selectedSkills.add(c.name) : _selectedSkills.remove(c.name);
                        }),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'CNIC front/back and selfie upload will be added once Storage wiring is in '
                'place — verification stays "under review" until an admin approves regardless.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                    : const Text('Submit for review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
