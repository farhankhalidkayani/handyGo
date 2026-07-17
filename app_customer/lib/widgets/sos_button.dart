import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_services.dart';

const _emergencyTypes = ['threat', 'violence', 'robbery', 'medical', 'accident', 'other'];

/// Plan §10.1: "press-and-hold 3s ... to activate" — the anti-accidental-trigger mechanism,
/// so a stray tap during an active job never files a false SOS. Risk level always comes from
/// eventRouter's rules tier (§9.9), never solely the LLM, so this stays reliable even if the
/// LLM tier is down.
class SosButton extends StatefulWidget {
  final String raisedByRole;
  final String raisedById;
  final String? bookingId;
  final String? counterpartId;

  const SosButton({
    super.key,
    required this.raisedByRole,
    required this.raisedById,
    this.bookingId,
    this.counterpartId,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  Timer? _holdTimer;
  double _progress = 0;
  bool _submitting = false;

  void _startHold() {
    if (_submitting) return;
    const tick = Duration(milliseconds: 100);
    const holdDuration = Duration(seconds: 3);
    var elapsed = Duration.zero;
    _holdTimer = Timer.periodic(tick, (timer) {
      elapsed += tick;
      setState(() => _progress = elapsed.inMilliseconds / holdDuration.inMilliseconds);
      if (elapsed >= holdDuration) {
        timer.cancel();
        setState(() => _progress = 0);
        _pickEmergencyType();
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    setState(() => _progress = 0);
  }

  Future<void> _pickEmergencyType() async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('What kind of emergency?'),
        children: _emergencyTypes
            .map((t) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(t),
                  child: Text(t),
                ))
            .toList(),
      ),
    );
    if (type == null || !mounted) return;
    await _raiseAlert(type);
  }

  Future<void> _raiseAlert(String emergencyType) async {
    setState(() => _submitting = true);
    try {
      double? lat;
      double? lng;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (_) {
        // SOS still files without location — never block on GPS
      }

      await AppServices.sos.raiseAlert(
        raisedByRole: widget.raisedByRole,
        raisedById: widget.raisedById,
        emergencyType: emergencyType,
        bookingId: widget.bookingId,
        counterpartId: widget.counterpartId,
        lat: lat,
        lng: lng,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS sent. Admin has been alerted.'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SOS failed to send: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: _cancelHold,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_progress > 0)
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(value: _progress, strokeWidth: 4, color: Colors.red),
            ),
          FloatingActionButton(
            backgroundColor: Colors.red,
            onPressed: null, // activation is via hold, not tap — see onTapDown/onTapUp above
            child: _submitting
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Icon(Icons.sos, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
