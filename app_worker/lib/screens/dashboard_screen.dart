import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'active_job_screen.dart';
import 'language_select_screen.dart';
import 'notifications_screen.dart';
import 'open_jobs_screen.dart';
import 'safety_center_screen.dart';
import 'wallet_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserProfile profile;
  final WorkerProfile worker;

  const DashboardScreen({
    super.key,
    required this.profile,
    required this.worker,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late WorkerProfile _worker;
  Booking? _activeJob;
  bool _loading = true;
  bool _togglingAvailability = false;
  String? _error;
  int _unreadCount = 0;
  double _todayEarnings = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
    _refresh();
    _loadUnreadCount();
    _loadTodayEarnings();
    // Polling instead of a realtime subscription: the raw bookings channel fans out every
    // booking in the whole app, not just this worker's, so under active load a
    // subscription-driven refresh would tear down/recreate the open-jobs FutureBuilder
    // faster than it could ever resolve. Plain fields updated via setState (rather than a
    // Future re-assigned into a FutureBuilder on every tick) avoid that instability
    // entirely — old data stays visible while a background refresh is in flight.
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refresh();
      _loadTodayEarnings();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodayEarnings() async {
    try {
      final transactions = await AppServices.transactions.listForWorkerToday(
        widget.profile.id,
      );
      final total = transactions.fold<double>(
        0,
        (sum, t) => sum + t.netToWorker,
      );
      if (mounted) setState(() => _todayEarnings = total);
    } catch (_) {
      // best-effort — dashboard still works without this
    }
  }

  Future<void> _loadUnreadCount() async {
    final notifications = await AppServices.notifications.listForUser(
      widget.profile.id,
    );
    if (!mounted) return;
    setState(() => _unreadCount = notifications.where((n) => !n.read).length);
  }

  Future<void> _openWallet() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WalletScreen(worker: _worker)));
    final refreshed = await AppServices.profiles.findWorkerProfileByUserId(
      widget.profile.id,
    );
    if (mounted && refreshed != null) setState(() => _worker = refreshed);
    _loadTodayEarnings();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(profile: widget.profile),
      ),
    );
    _loadUnreadCount();
  }

  Future<void> _refresh() async {
    final activeJob = await AppServices.bookings.findActiveForWorker(
      widget.profile.id,
    );
    if (!mounted) return;
    setState(() {
      _activeJob = activeJob;
      _loading = false;
    });
  }

  Future<void> _pullToRefresh() async {
    await _refresh();
    await _loadTodayEarnings();
    await _loadUnreadCount();
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
          currentLat: _worker.currentLat,
          currentLng: _worker.currentLng,
          walletBalance: _worker.walletBalance,
          pendingBalance: _worker.pendingBalance,
          performanceScore: _worker.performanceScore,
        );
      });
      await _refresh();
    } catch (e) {
      setState(() => _error = 'Could not update availability: $e');
    } finally {
      if (mounted) setState(() => _togglingAvailability = false);
    }
  }

  void _openActiveJob(Booking booking) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                ActiveJobScreen(profile: widget.profile, bookingId: booking.id),
          ),
        )
        .then((_) => _refresh());
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
    final scheme = Theme.of(context).colorScheme;
    final online = _worker.availability == 'online';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Safety Center',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SafetyCenterScreen(profile: widget.profile),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Wallet',
            onPressed: _openWallet,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _openNotifications,
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: TextStyle(color: scheme.onError, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Builder(
        builder: (context) {
          final activeJob = _activeJob;
          return RefreshIndicator(
            onRefresh: _pullToRefresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          widget.profile.name.isNotEmpty
                              ? widget.profile.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${widget.profile.name}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Colors.amber.shade600,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    '${_worker.rating.toStringAsFixed(1)} · ${_worker.jobsCompleted} jobs · ${_worker.skills.join(', ')}',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          scheme.primary.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DashboardStat(
                          label: 'Today',
                          value: 'Rs. ${_todayEarnings.toStringAsFixed(0)}',
                          onColor: scheme.onPrimary,
                        ),
                        _DashboardStat(
                          label: 'Wallet',
                          value:
                              'Rs. ${_worker.walletBalance.toStringAsFixed(0)}',
                          onColor: scheme.onPrimary,
                        ),
                        _DashboardStat(
                          label: 'Performance',
                          value: '${_worker.performanceScore}/100',
                          onColor: scheme.onPrimary,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        online ? 'Online — receiving jobs' : 'Offline',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      secondary: Icon(
                        online
                            ? Icons.wifi_tethering
                            : Icons.wifi_tethering_off,
                        color: online ? Colors.green : scheme.onSurfaceVariant,
                      ),
                      value: online,
                      onChanged: _togglingAvailability
                          ? null
                          : _toggleAvailability,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 20),
                  if (activeJob != null) ...[
                    Text(
                      'Active job',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openActiveJob(activeJob),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.build_outlined,
                                color: scheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeJob.problemText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSecondaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      activeJob.status.wire,
                                      style: TextStyle(
                                        color: scheme.onSecondaryContainer
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: scheme.onSecondaryContainer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                  ] else if (!online) ...[
                    _EmptyHint(
                      icon: Icons.wifi_tethering_off,
                      text: 'Go online to see incoming job requests.',
                    ),
                  ] else ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OpenJobsScreen(
                              profile: widget.profile,
                              worker: _worker,
                            ),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.work_outline,
                                color: scheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'View open jobs matching your skills',
                                  style: TextStyle(
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: scheme.onPrimaryContainer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  final String label;
  final String value;
  final Color onColor;

  const _DashboardStat({
    required this.label,
    required this.value,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: onColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: onColor.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
