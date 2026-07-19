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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.person_outline, size: 32, color: scheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                        labelText: 'Phone (e.g. +923001234567)', prefixIcon: Icon(Icons.phone_outlined)),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: scheme.error)),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_forward),
                    label: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
