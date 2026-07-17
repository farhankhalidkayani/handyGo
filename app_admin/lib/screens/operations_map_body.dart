import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:handygo_shared/handygo_shared.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../services/app_services.dart';

const _statusColors = {
  BookingStatus.searchingWorkers: Colors.grey,
  BookingStatus.offersReceived: Colors.grey,
  BookingStatus.workerSelected: Colors.blue,
  BookingStatus.confirmed: Colors.blue,
  BookingStatus.workerOnTheWay: Colors.orange,
  BookingStatus.workerArrived: Colors.orange,
  BookingStatus.serviceStarted: Colors.green,
  BookingStatus.inProgress: Colors.green,
  BookingStatus.completionRequested: Colors.teal,
  BookingStatus.paymentPending: Colors.teal,
  BookingStatus.disputed: Colors.purple,
};

/// Plan §12 Admin Panel checklist: "Live operations map (marker statuses incl. SOS)".
class OperationsMapBody extends StatefulWidget {
  const OperationsMapBody({super.key});

  @override
  State<OperationsMapBody> createState() => _OperationsMapBodyState();
}

class _OperationsMapBodyState extends State<OperationsMapBody> {
  List<Booking> _activeBookings = [];
  List<SosAlert> _sosAlerts = [];
  RealtimeSubscription? _bookingSub;
  RealtimeSubscription? _sosSub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _bookingSub = AppServices.bookings.subscribeToBookings();
    _bookingSub!.stream.listen((event) {
      final booking = Booking.fromMap(event.payload);
      setState(() {
        _activeBookings.removeWhere((b) => b.id == booking.id);
        if (![BookingStatus.completed, BookingStatus.cancelled, BookingStatus.refunded].contains(booking.status)) {
          _activeBookings.add(booking);
        }
      });
    });
    _sosSub = AppServices.sos.subscribeToSosAlerts();
    _sosSub!.stream.listen((event) {
      final alert = SosAlert.fromMap(event.payload);
      setState(() {
        _sosAlerts.removeWhere((a) => a.id == alert.id);
        if (alert.adminStatus != 'closed') _sosAlerts.add(alert);
      });
    });
  }

  Future<void> _load() async {
    final all = await AppServices.bookings.listAllBookings();
    final sos = await AppServices.sos.listOpenAlerts();
    if (!mounted) return;
    setState(() {
      _activeBookings = all
          .where((b) => ![BookingStatus.completed, BookingStatus.cancelled, BookingStatus.refunded].contains(b.status))
          .toList();
      _sosAlerts = sos;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _bookingSub?.close();
    _sosSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final bookingMarkers = _activeBookings
        .where((b) => b.lat != 0 || b.lng != 0)
        .map((b) => Marker(
              point: latlong.LatLng(b.lat, b.lng),
              child: Tooltip(
                message: '${b.problemText}\n${b.status.wire}',
                child: Icon(Icons.circle, color: _statusColors[b.status] ?? Colors.grey, size: 18),
              ),
            ))
        .toList();
    final sosMarkers = _sosAlerts
        .where((a) => a.lat != null && a.lng != null)
        .map((a) => Marker(
              point: latlong.LatLng(a.lat!, a.lng!),
              child: const Tooltip(
                message: 'SOS alert',
                child: Icon(Icons.warning, color: Colors.red, size: 26),
              ),
            ))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 12,
            children: [
              _Legend(color: Colors.blue, label: 'Confirmed'),
              _Legend(color: Colors.orange, label: 'On the way'),
              _Legend(color: Colors.green, label: 'In progress'),
              _Legend(color: Colors.purple, label: 'Disputed'),
              _Legend(color: Colors.red, label: 'SOS'),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: const MapOptions(initialCenter: latlong.LatLng(24.86, 67.01), initialZoom: 11),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.handygo.admin',
              ),
              MarkerLayer(markers: [...bookingMarkers, ...sosMarkers]),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
