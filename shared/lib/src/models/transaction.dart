/// Mirrors the `transactions` collection (§5.11) — created only by transitionBooking.js on
/// a booking's `completed` transition (commission/netToWorker are server-only, §11).
class BookingTransaction {
  final String id;
  final String bookingId;
  final String customerId;
  final String workerId;
  final double serviceCharges;
  final double materialCharges;
  final double platformFee;
  final double discount;
  final double total;
  final String method;
  final String status;
  final double commission;
  final double netToWorker;
  final DateTime createdAt;

  const BookingTransaction({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.workerId,
    required this.serviceCharges,
    required this.materialCharges,
    required this.platformFee,
    required this.discount,
    required this.total,
    required this.method,
    required this.status,
    required this.commission,
    required this.netToWorker,
    required this.createdAt,
  });

  factory BookingTransaction.fromMap(Map<String, dynamic> map) => BookingTransaction(
        id: map['\$id'] as String,
        bookingId: map['bookingId'] as String? ?? '',
        customerId: map['customerId'] as String? ?? '',
        workerId: map['workerId'] as String? ?? '',
        serviceCharges: (map['serviceCharges'] as num?)?.toDouble() ?? 0,
        materialCharges: (map['materialCharges'] as num?)?.toDouble() ?? 0,
        platformFee: (map['platformFee'] as num?)?.toDouble() ?? 0,
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
        total: (map['total'] as num?)?.toDouble() ?? 0,
        method: map['method'] as String? ?? 'cod',
        status: map['status'] as String? ?? 'paid',
        commission: (map['commission'] as num?)?.toDouble() ?? 0,
        netToWorker: (map['netToWorker'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(map['\$createdAt'] as String? ?? '') ?? DateTime(2000),
      );
}
