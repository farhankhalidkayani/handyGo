import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §9 (Phase 9 "Polish & real-feel"): "notifications by role". Admin notifications use
/// the shared `userId: "admin"` sentinel (SOS/fraud/chat-flag alerts broadcast to every
/// admin), not one specific admin's own id — see notification_repository.dart.
class NotificationsBody extends StatefulWidget {
  const NotificationsBody({super.key});

  @override
  State<NotificationsBody> createState() => _NotificationsBodyState();
}

class _NotificationsBodyState extends State<NotificationsBody> {
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
      if (n.userId != 'admin') return;
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
    final list = await AppServices.notifications.listForUser('admin');
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
        // best-effort
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_notifications.isEmpty) return const Center(child: Text('No notifications yet.'));
    return ListView.builder(
      itemCount: _notifications.length,
      itemBuilder: (context, i) {
        final n = _notifications[i];
        return ListTile(
          leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active,
              color: n.read ? Colors.grey : Theme.of(context).colorScheme.primary),
          title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
          subtitle: n.body != null && n.body!.isNotEmpty ? Text(n.body!) : null,
          trailing: n.bookingId != null ? const Icon(Icons.chevron_right) : null,
          onTap: () => _tap(n),
        );
      },
    );
  }
}
