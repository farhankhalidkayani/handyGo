import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:handygo_shared/handygo_shared.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:url_launcher/url_launcher.dart';

import '../services/app_services.dart';

const _riskColors = {
  'critical': Colors.red,
  'high': Colors.orange,
  'medium': Colors.amber,
  'low': Colors.grey,
};

/// Plan §10.3: "Admin SOS Control Center — red banner + incident timeline + actions (Open
/// Live Location, Call parties, Pause Booking, Block Payment, Cancel, Suspend, Mark Safe,
/// Close)". All actions implemented.
class SosControlCenterBody extends StatefulWidget {
  const SosControlCenterBody({super.key});

  @override
  State<SosControlCenterBody> createState() => _SosControlCenterBodyState();
}

class _SosControlCenterBodyState extends State<SosControlCenterBody> {
  final List<SosAlert> _alerts = [];
  RealtimeSubscription? _subscription;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = AppServices.sos.subscribeToSosAlerts();
    _subscription!.stream.listen((event) {
      final alert = SosAlert.fromMap(event.payload);
      setState(() {
        final i = _alerts.indexWhere((a) => a.id == alert.id);
        if (i != -1) {
          if (alert.adminStatus == 'closed') {
            _alerts.removeAt(i);
          } else {
            _alerts[i] = alert;
          }
        } else if (alert.adminStatus != 'closed') {
          _alerts.insert(0, alert);
        }
      });
    });
  }

  Future<void> _load() async {
    final alerts = await AppServices.sos.listOpenAlerts();
    if (!mounted) return;
    setState(() {
      _alerts
        ..clear()
        ..addAll(alerts);
      _loading = false;
    });
  }

  Future<void> _updateStatus(SosAlert alert, String status) async {
    setState(() => _error = null);
    try {
      await AppServices.sos.updateStatus(
        sosAlertId: alert.id,
        adminStatus: status,
      );
    } catch (e) {
      setState(() => _error = 'Action failed: $e');
    }
  }

  Future<void> _callRaiser(SosAlert alert) async {
    setState(() => _error = null);
    try {
      final raiser = await AppServices.profiles.findById(alert.raisedById);
      final phone = raiser?.phone;
      if (phone == null || phone.isEmpty) {
        setState(() => _error = 'No phone number on file for this user');
        return;
      }
      final uri = Uri(scheme: 'tel', path: phone);
      if (!await launchUrl(uri)) {
        setState(() => _error = 'Could not launch phone dialer');
      }
    } catch (e) {
      setState(() => _error = 'Call failed: $e');
    }
  }

  Future<void> _suspendCounterpart(SosAlert alert) async {
    if (alert.counterpartId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend this account?'),
        content: const Text(
          'This immediately blocks the counterpart from using the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _error = null);
    try {
      await AppServices.sos.updateStatus(
        sosAlertId: alert.id,
        adminStatus: alert.adminStatus,
        action: 'Suspended counterpart account',
        suspendUserId: alert.counterpartId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account suspended.')));
    } catch (e) {
      setState(() => _error = 'Suspend failed: $e');
    }
  }

  void _openLiveLocation(SosAlert alert) {
    if (alert.lat == null || alert.lng == null) {
      setState(() => _error = 'No location was captured for this alert');
      return;
    }
    final pos = latlong.LatLng(alert.lat!, alert.lng!);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          height: 320,
          width: 400,
          child: FlutterMap(
            options: MapOptions(initialCenter: pos, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.handygo.admin',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pos,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bookingAction(
    SosAlert alert,
    String bookingAction, {
    String? confirmMessage,
  }) async {
    if (alert.bookingId == null) {
      setState(() => _error = 'This alert has no associated booking');
      return;
    }
    if (confirmMessage != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(confirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _error = null);
    try {
      await AppServices.sos.updateStatus(
        sosAlertId: alert.id,
        adminStatus: alert.adminStatus,
        action: bookingAction,
        bookingAction: bookingAction,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking action "$bookingAction" applied.')),
      );
    } catch (e) {
      setState(() => _error = 'Action failed: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: TextStyle(color: scheme.error)),
          ),
        if (_alerts.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 40,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No open SOS alerts.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _alerts.length,
                itemBuilder: (context, i) {
                  final a = _alerts[i];
                  final riskColor = _riskColors[a.aiRiskLevel] ?? Colors.grey;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border(
                        left: BorderSide(color: riskColor, width: 4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: riskColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: riskColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${a.emergencyType.toUpperCase()} — ${(a.aiRiskLevel ?? 'unknown').toUpperCase()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: riskColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Raised by ${a.raisedByRole} ${a.raisedById}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          if (a.aiSummary != null) ...[
                            const SizedBox(height: 8),
                            Text(a.aiSummary!),
                          ],
                          if (a.aiSuggestedActions.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: a.aiSuggestedActions
                                  .map(
                                    (s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.surface,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        s,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    _updateStatus(a, 'acknowledged'),
                                child: const Text('Acknowledge'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _updateStatus(a, 'in_progress'),
                                child: const Text('In progress'),
                              ),
                              FilledButton(
                                onPressed: () => _updateStatus(a, 'safe'),
                                child: const Text('Mark safe'),
                              ),
                              OutlinedButton(
                                onPressed: () => _updateStatus(a, 'closed'),
                                child: const Text('Close'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _callRaiser(a),
                                icon: const Icon(Icons.call, size: 16),
                                label: const Text('Call raiser'),
                              ),
                              if (a.counterpartId != null)
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  onPressed: () => _suspendCounterpart(a),
                                  child: const Text('Suspend counterpart'),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => _openLiveLocation(a),
                                icon: const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                ),
                                label: const Text('Open live location'),
                              ),
                              if (a.bookingId != null) ...[
                                OutlinedButton(
                                  onPressed: () => _bookingAction(a, 'pause'),
                                  child: const Text('Pause booking'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _bookingAction(a, 'unpause'),
                                  child: const Text('Resume booking'),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      _bookingAction(a, 'blockPayment'),
                                  child: const Text('Block payment'),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      _bookingAction(a, 'unblockPayment'),
                                  child: const Text('Unblock payment'),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  onPressed: () => _bookingAction(
                                    a,
                                    'cancel',
                                    confirmMessage: 'Cancel this booking?',
                                  ),
                                  child: const Text('Cancel booking'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
