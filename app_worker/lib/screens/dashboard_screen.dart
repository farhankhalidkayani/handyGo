import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'active_job_screen.dart';
import 'language_select_screen.dart';
import 'notifications_screen.dart';
import 'send_offer_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserProfile profile;
  final WorkerProfile worker;

  const DashboardScreen({super.key, required this.profile, required this.worker});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late WorkerProfile _worker;
  Future<Booking?>? _activeJobFuture;
  Future<List<Booking>>? _openJobsFuture;
  bool _togglingAvailability = false;
  String? _error;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
    _refresh();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final notifications = await AppServices.notifications.listForUser(widget.profile.id);
    if (!mounted) return;
    setState(() => _unreadCount = notifications.where((n) => !n.read).length);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationsScreen(profile: widget.profile)),
    );
    _loadUnreadCount();
  }

  void _refresh() {
    _activeJobFuture = AppServices.bookings.findActiveForWorker(widget.profile.id);
    if (_worker.availability == 'online') {
      _openJobsFuture = _loadOpenJobs();
    }
  }

  Future<List<Booking>> _loadOpenJobs() async {
    final categories = await AppServices.categories.listAll();
    final categoryIds = categories.where((c) => _worker.skills.contains(c.name)).map((c) => c.id).toList();
    return AppServices.bookings.listOpenBookings(categoryIds);
  }

  Future<void> _toggleAvailability(bool online) async {
    setState(() {
      _togglingAvailability = true;
      _error = null;
    });
    try {
      await AppServices.profiles.updateWorkerAvailability(
        workerProfileId: _worker.id,
        availability: online ? 'online' : 'offline',
      );
      setState(() {
        _worker = WorkerProfile(
          id: _worker.id,
          userId: _worker.userId,
          skills: _worker.skills,
          verificationStatus: _worker.verificationStatus,
          availability: online ? 'online' : 'offline',
          rating: _worker.rating,
          jobsCompleted: _worker.jobsCompleted,
        );
        _refresh();
      });
    } catch (e) {
      setState(() => _error = 'Could not update availability: $e');
    } finally {
      if (mounted) setState(() => _togglingAvailability = false);
    }
  }

  Future<void> _sendOffer(Booking booking) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SendOfferScreen(profile: widget.profile, booking: booking),
      ),
    );
    if (sent == true && mounted) setState(_refresh);
  }

  void _openActiveJob(Booking booking) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ActiveJobScreen(profile: widget.profile, bookingId: booking.id)))
        .then((_) => setState(_refresh));
  }

  Future<void> _logout(BuildContext context) async {
    await AppServices.auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LanguageSelectScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: _openNotifications),
              if (_unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
        ],
      ),
      body: FutureBuilder<Booking?>(
        future: _activeJobFuture,
        builder: (context, activeSnapshot) {
          final activeJob = activeSnapshot.data;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Welcome, ${widget.profile.name}', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Skills: ${_worker.skills.join(', ')}'),
              Text('Rating: ${_worker.rating.toStringAsFixed(1)} · Jobs completed: ${_worker.jobsCompleted}'),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Online'),
                value: _worker.availability == 'online',
                onChanged: _togglingAvailability ? null : _toggleAvailability,
              ),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              if (activeJob != null) ...[
                const Text('Active job', style: TextStyle(fontWeight: FontWeight.bold)),
                Card(
                  child: ListTile(
                    title: Text(activeJob.problemText),
                    subtitle: Text(activeJob.status.wire),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openActiveJob(activeJob),
                  ),
                ),
              ] else if (_worker.availability != 'online') ...[
                const Text('Go online to see incoming job requests.'),
              ] else ...[
                const Text('Open jobs matching your skills', style: TextStyle(fontWeight: FontWeight.bold)),
                FutureBuilder<List<Booking>>(
                  future: _openJobsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final jobs = snapshot.data!;
                    if (jobs.isEmpty) return const Text('No open jobs right now.');
                    return Column(
                      children: jobs
                          .map((b) => Card(
                                child: ListTile(
                                  title: Text(b.problemText),
                                  subtitle: Text(b.addressText),
                                  trailing: FilledButton(
                                    onPressed: () => _sendOffer(b),
                                    child: const Text('Offer'),
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
