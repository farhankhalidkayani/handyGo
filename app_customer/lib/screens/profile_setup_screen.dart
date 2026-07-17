import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'home_screen.dart';

/// Runs once, right after the first successful OTP login for a brand-new Auth user (no
/// `users` document yet) — see plan §12 Customer App checklist.
class ProfileSetupScreen extends StatefulWidget {
  final String authId;
  final String email;
  final String language;

  const ProfileSetupScreen({
    super.key,
    required this.authId,
    required this.email,
    required this.language,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      double? lat;
      double? lng;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (_) {
        // location optional at this step — booking screens will ask again if still missing
      }

      final userDoc = await AppServices.profiles.createUserDocument(
        authId: widget.authId,
        role: 'customer',
        name: _nameController.text.trim(),
        email: widget.email,
        phone: _phoneController.text.trim(),
        language: widget.language,
      );
      await AppServices.profiles.createCustomerProfile(
        authId: widget.authId,
        userId: userDoc.$id,
        lat: lat,
        lng: lng,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            profile: UserProfile.fromMap({...userDoc.data, '\$id': userDoc.$id}),
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = 'Could not save profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
