import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §12 Admin Panel checklist: "Payments & finance audit". Read-only — transactions are
/// only ever created server-side by transitionBooking.js on a booking's `completed`
/// transition, so there's nothing for the admin to edit here, only review.
class FinanceBody extends StatefulWidget {
  const FinanceBody({super.key});

  @override
  State<FinanceBody> createState() => _FinanceBodyState();
}

class _FinanceBodyState extends State<FinanceBody> {
  List<BookingTransaction> _transactions = [];
  List<WalletWithdrawal> _withdrawals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final transactions = await AppServices.transactions.listRecent();
      final withdrawals = await AppServices.transactions.listRecentWithdrawals();
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _withdrawals = withdrawals;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load transactions: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: scheme.error)));
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text('No transactions yet.', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final totalRevenue = _transactions.fold<double>(0, (sum, t) => sum + t.total);
    final totalCommission = _transactions.fold<double>(0, (sum, t) => sum + t.commission);
    final totalPaidToWorkers = _transactions.fold<double>(0, (sum, t) => sum + t.netToWorker);
    final totalWithdrawn = _withdrawals.fold<double>(0, (sum, w) => sum + w.amount);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(icon: Icons.payments_outlined, label: 'Total revenue', value: 'Rs. ${totalRevenue.toStringAsFixed(0)}'),
                _StatCard(icon: Icons.percent_outlined, label: 'Platform commission', value: 'Rs. ${totalCommission.toStringAsFixed(0)}'),
                _StatCard(icon: Icons.engineering_outlined, label: 'Paid to workers', value: 'Rs. ${totalPaidToWorkers.toStringAsFixed(0)}'),
                _StatCard(icon: Icons.arrow_circle_down_outlined, label: 'Withdrawn', value: 'Rs. ${totalWithdrawn.toStringAsFixed(0)}'),
              ],
            ),
          ),
          TabBar(
            tabs: const [Tab(text: 'Transactions'), Tab(text: 'Withdrawals')],
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            indicatorColor: scheme.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _transactions.length,
                  itemBuilder: (context, i) {
                    final t = _transactions[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(Icons.receipt_outlined, size: 18, color: scheme.onPrimaryContainer),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Rs. ${t.total.toStringAsFixed(0)} — ${t.method.toUpperCase()} (${t.status})',
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  'Service: Rs. ${t.serviceCharges.toStringAsFixed(0)} · Materials: Rs. ${t.materialCharges.toStringAsFixed(0)}\n'
                                  'Commission: Rs. ${t.commission.toStringAsFixed(0)} · Net to worker: Rs. ${t.netToWorker.toStringAsFixed(0)}',
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _withdrawals.isEmpty
                    ? Center(child: Text('No withdrawals yet.', style: TextStyle(color: scheme.onSurfaceVariant)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _withdrawals.length,
                        itemBuilder: (context, i) {
                          final w = _withdrawals[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: scheme.secondaryContainer,
                                  child: Icon(Icons.arrow_circle_down_outlined, size: 18, color: scheme.onSecondaryContainer),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Rs. ${w.amount.toStringAsFixed(0)} — ${w.status}',
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text('Worker: ${w.workerId} · ${w.createdAt.toLocal()}',
                                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No failed-payment view — payment is instant COD settlement (no gateway that '
              'can actually fail), so there\'s nothing that scenario would show today.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}
