/// Mirrors the `wallet_withdrawals` collection — an audit log for withdrawWallet.js, since a
/// real payout rail is out of scope for this FYP (see that file's comment) but the Admin
/// Finance tab still needs something real to show.
class WalletWithdrawal {
  final String id;
  final String workerId;
  final double amount;
  final String status;
  final DateTime createdAt;

  const WalletWithdrawal({
    required this.id,
    required this.workerId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory WalletWithdrawal.fromMap(Map<String, dynamic> map) => WalletWithdrawal(
        id: map['\$id'] as String,
        workerId: map['workerId'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        status: map['status'] as String? ?? 'completed',
        createdAt: DateTime.tryParse(map['\$createdAt'] as String? ?? '') ?? DateTime(2000),
      );
}
