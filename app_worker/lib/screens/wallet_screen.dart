import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §12 Worker App checklist: "Wallet + withdraw + AI performance tips".
class WalletScreen extends StatefulWidget {
  final WorkerProfile worker;

  const WalletScreen({super.key, required this.worker});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late WorkerProfile _worker;
  String? _tip;
  bool _loadingTip = true;
  bool _withdrawing = false;
  String? _error;
  String? _message;
  RealtimeSubscription? _profileSub;

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
    _loadTip();
    _profileSub = AppServices.profiles.subscribeToWorkerProfiles();
    _profileSub!.stream.listen((event) {
      if (!mounted) return;
      final updated = WorkerProfile.fromMap(event.payload);
      if (updated.id != _worker.id) return;
      setState(() => _worker = updated);
    });
  }

  @override
  void dispose() {
    _profileSub?.close();
    super.dispose();
  }

  Future<void> _loadTip() async {
    try {
      final result = await AppServices.profiles.getPerformanceTip(_worker);
      if (!mounted) return;
      setState(() => _tip = result['tip'] as String?);
    } catch (_) {
      // tips are a nice-to-have — never block the wallet screen
    } finally {
      if (mounted) setState(() => _loadingTip = false);
    }
  }

  Future<void> _withdraw() async {
    if (_worker.walletBalance <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Withdraw Rs. ${_worker.walletBalance.toStringAsFixed(0)}?',
        ),
        content: const Text(
          'A real payout method (bank transfer/JazzCash/etc.) is out of scope for this build — '
          'this simulates an instant payout, same as how payment itself is simulated as COD.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _withdrawing = true;
      _error = null;
      _message = null;
    });
    try {
      final result = await AppServices.profiles.withdrawWallet(_worker.id);
      final amount = (result['withdrawn'] as num?)?.toDouble() ?? 0;
      setState(() {
        _worker = WorkerProfile(
          id: _worker.id,
          userId: _worker.userId,
          skills: _worker.skills,
          verificationStatus: _worker.verificationStatus,
          availability: _worker.availability,
          rating: _worker.rating,
          jobsCompleted: _worker.jobsCompleted,
          currentLat: _worker.currentLat,
          currentLng: _worker.currentLng,
          walletBalance: 0,
          pendingBalance: _worker.pendingBalance,
          performanceScore: _worker.performanceScore,
        );
        _message = 'Withdrew Rs. ${amount.toStringAsFixed(0)}.';
      });
    } catch (e) {
      setState(() => _error = 'Could not withdraw: $e');
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.primary.withValues(alpha: 0.7)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: scheme.onPrimary.withValues(alpha: 0.9),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Available balance',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs. ${_worker.walletBalance.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Pending: Rs. ${_worker.pendingBalance.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_withdrawing || _worker.walletBalance <= 0)
                ? null
                : _withdraw,
            icon: _withdrawing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_circle_down_outlined),
            label: const Text('Withdraw'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _message!,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 28),
          Text('Performance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    icon: Icons.speed_outlined,
                    label: 'Performance',
                    value: '${_worker.performanceScore}/100',
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _StatColumn(
                    icon: Icons.star_outline,
                    label: 'Rating',
                    value: _worker.rating.toStringAsFixed(1),
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _StatColumn(
                    icon: Icons.task_alt_outlined,
                    label: 'Jobs done',
                    value: '${_worker.jobsCompleted}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingTip)
            const Center(child: CircularProgressIndicator())
          else if (_tip != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _tip!,
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
        ),
      ],
    );
  }
}
