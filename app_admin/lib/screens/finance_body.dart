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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_transactions.isEmpty) return const Center(child: Text('No transactions yet.'));

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
                _StatCard(label: 'Total revenue', value: 'Rs. ${totalRevenue.toStringAsFixed(0)}'),
                _StatCard(label: 'Platform commission', value: 'Rs. ${totalCommission.toStringAsFixed(0)}'),
                _StatCard(label: 'Paid to workers', value: 'Rs. ${totalPaidToWorkers.toStringAsFixed(0)}'),
                _StatCard(label: 'Withdrawn', value: 'Rs. ${totalWithdrawn.toStringAsFixed(0)}'),
              ],
            ),
          ),
          const TabBar(tabs: [Tab(text: 'Transactions'), Tab(text: 'Withdrawals')]),
          Expanded(
            child: TabBarView(
              children: [
                ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, i) {
                    final t = _transactions[i];
                    return ListTile(
                      title: Text('Rs. ${t.total.toStringAsFixed(0)} — ${t.method.toUpperCase()} (${t.status})'),
                      subtitle: Text(
                        'Service: Rs. ${t.serviceCharges.toStringAsFixed(0)} · Materials: Rs. ${t.materialCharges.toStringAsFixed(0)}\n'
                        'Commission: Rs. ${t.commission.toStringAsFixed(0)} · Net to worker: Rs. ${t.netToWorker.toStringAsFixed(0)}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
                _withdrawals.isEmpty
                    ? const Center(child: Text('No withdrawals yet.'))
                    : ListView.builder(
                        itemCount: _withdrawals.length,
                        itemBuilder: (context, i) {
                          final w = _withdrawals[i];
                          return ListTile(
                            title: Text('Rs. ${w.amount.toStringAsFixed(0)} — ${w.status}'),
                            subtitle: Text('Worker: ${w.workerId} · ${w.createdAt.toLocal()}'),
                          );
                        },
                      ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'No failed-payment view — payment is instant COD settlement (no gateway that '
              'can actually fail), so there\'s nothing that scenario would show today.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
