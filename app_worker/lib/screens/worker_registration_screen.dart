import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:handygo_shared/handygo_shared.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_services.dart';
import 'under_review_screen.dart';

/// Plan §12 Worker App checklist: "Registration (CNIC, selfie, skills, area, docs) →
/// under-review state".
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

  String? _cnicFrontId;
  String? _cnicBackId;
  String? _selfieId;
  bool _uploadingCnicFront = false;
  bool _uploadingCnicBack = false;
  bool _uploadingSelfie = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = AppServices.categories.listAll();
  }

  Future<void> _captureCnicFront() async {
    setState(() => _uploadingCnicFront = true);
    try {
      final id = await _pickAndUpload();
      if (id != null) setState(() => _cnicFrontId = id);
    } catch (e) {
      setState(() => _error = 'Could not capture CNIC front: $e');
    } finally {
      if (mounted) setState(() => _uploadingCnicFront = false);
    }
  }

  Future<void> _captureCnicBack() async {
    setState(() => _uploadingCnicBack = true);
    try {
      final id = await _pickAndUpload();
      if (id != null) setState(() => _cnicBackId = id);
    } catch (e) {
      setState(() => _error = 'Could not capture CNIC back: $e');
    } finally {
      if (mounted) setState(() => _uploadingCnicBack = false);
    }
  }

  Future<void> _captureSelfie() async {
    setState(() => _uploadingSelfie = true);
    try {
      final id = await _pickAndUpload(source: ImageSource.camera);
      if (id != null) setState(() => _selfieId = id);
    } catch (e) {
      setState(() => _error = 'Could not capture selfie: $e');
    } finally {
      if (mounted) setState(() => _uploadingSelfie = false);
    }
  }

  Future<String?> _pickAndUpload({ImageSource source = ImageSource.gallery}) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return AppServices.media.uploadImage(bytes: bytes, filename: picked.name);
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
        cnicFrontUrl: _cnicFrontId,
        cnicBackUrl: _cnicBackId,
        selfieUrl: _selfieId,
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
              const SizedBox(height: 16),
              const Text('Verification documents', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploadingCnicFront ? null : _captureCnicFront,
                icon: _uploadingCnicFront
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_cnicFrontId != null ? Icons.check_circle : Icons.badge_outlined),
                label: Text(_cnicFrontId != null ? 'CNIC front captured' : 'Capture CNIC front'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploadingCnicBack ? null : _captureCnicBack,
                icon: _uploadingCnicBack
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_cnicBackId != null ? Icons.check_circle : Icons.badge_outlined),
                label: Text(_cnicBackId != null ? 'CNIC back captured' : 'Capture CNIC back'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploadingSelfie ? null : _captureSelfie,
                icon: _uploadingSelfie
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_selfieId != null ? Icons.check_circle : Icons.face_outlined),
                label: Text(_selfieId != null ? 'Selfie captured' : 'Capture selfie'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Documents help an admin verify your identity faster, but aren\'t required to '
                'submit — verification stays "under review" until an admin approves regardless.',
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
