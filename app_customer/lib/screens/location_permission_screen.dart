import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_screen.dart';

class LocationPermissionScreen extends StatelessWidget {
  final String language;

  const LocationPermissionScreen({super.key, required this.language});

  Future<void> _continue(BuildContext context, {required bool requestPermission}) async {
    if (requestPermission) {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
      }
    }
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => AuthScreen(language: language)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.location_on, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Handy Go uses your location to find nearby verified workers and show accurate ETAs.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _continue(context, requestPermission: true),
              child: const Text('Allow location access'),
            ),
            TextButton(
              onPressed: () => _continue(context, requestPermission: false),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}
