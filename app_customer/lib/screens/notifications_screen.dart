import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'tracking_screen.dart';

/// Plan §9 (Phase 9 "Polish & real-feel"): "notifications by role". Every write across the
/// backend (offer accepted, verification, SOS, fraud, charge decisions, ...) already creates
/// a `notifications` document — this is the first screen that actually shows them to a user.
class NotificationsScreen extends StatefulWidget {
  final UserProfile profile;

  const NotificationsScreen({super.key, required this.profile});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<AppNotification> _notifications = [];
  RealtimeSubscription? _subscription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = AppServices.notifications.subscribeToNotifications();
    _subscription!.stream.listen((event) {
      final n = AppNotification.fromMap(event.payload);
      if (n.userId != widget.profile.id) return;
      setState(() {
        final i = _notifications.indexWhere((x) => x.id == n.id);
        if (i != -1) {
          _notifications[i] = n;
        } else {
          _notifications.insert(0, n);
        }
      });
    });
  }

  Future<void> _load() async {
    final list = await AppServices.notifications.listForUser(widget.profile.id);
    if (!mounted) return;
    setState(() {
      _notifications
        ..clear()
        ..addAll(list);
      _loading = false;
    });
  }

  Future<void> _tap(AppNotification n) async {
    if (!n.read) {
      try {
        await AppServices.notifications.markRead(n.id);
      } catch (_) {
        // best-effort — not marking read shouldn't block navigating to the booking
      }
    }
    if (n.bookingId != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TrackingScreen(profile: widget.profile, bookingId: n.bookingId!),
        ),
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 40,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No notifications yet.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _notifications.length,
                itemBuilder: (context, i) {
                  final n = _notifications[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: n.read
                          ? Colors.transparent
                          : scheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: n.read
                            ? scheme.surfaceContainerHighest
                            : scheme.primary,
                        child: Icon(
                          n.read
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          size: 18,
                          color: n.read
                              ? scheme.onSurfaceVariant
                              : scheme.onPrimary,
                        ),
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight: n.read
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                      subtitle: n.body != null && n.body!.isNotEmpty
                          ? Text(n.body!)
                          : null,
                      trailing: n.bookingId != null
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: () => _tap(n),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
