import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
    _loadTip();
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
        title: Text('Withdraw Rs. ${_worker.walletBalance.toStringAsFixed(0)}?'),
        content: const Text(
          'A real payout method (bank transfer/JazzCash/etc.) is out of scope for this build — '
          'this simulates an instant payout, same as how payment itself is simulated as COD.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Withdraw')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available balance', style: TextStyle(color: Colors.grey)),
                  Text('Rs. ${_worker.walletBalance.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Pending: Rs. ${_worker.pendingBalance.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_withdrawing || _worker.walletBalance <= 0) ? null : _withdraw,
            child: _withdrawing
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                : const Text('Withdraw'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message!, style: const TextStyle(color: Colors.green)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 32),
          Text('Performance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Score: ${_worker.performanceScore}/100'),
          Text('Rating: ${_worker.rating.toStringAsFixed(1)} · Jobs completed: ${_worker.jobsCompleted}'),
          const SizedBox(height: 12),
          if (_loadingTip)
            const Center(child: CircularProgressIndicator())
          else if (_tip != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_tip!)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
