/// Mirrors the `worker_offers` collection (§5.6) — the InDrive-style offer list.
class WorkerOffer {
  final String id;
  final String bookingId;
  final String workerId;
  final double quote;
  final int? etaMins;
  final double? distanceKm;
  final String? message;
  final String status;
  final bool isBestMatch;
  final bool flaggedSuspicious;

  const WorkerOffer({
    required this.id,
    required this.bookingId,
    required this.workerId,
    required this.quote,
    this.etaMins,
    this.distanceKm,
    this.message,
    this.status = 'sent',
    this.isBestMatch = false,
    this.flaggedSuspicious = false,
  });

  factory WorkerOffer.fromMap(Map<String, dynamic> map) => WorkerOffer(
        id: map['\$id'] as String,
        bookingId: map['bookingId'] as String,
        workerId: map['workerId'] as String,
        quote: (map['quote'] as num).toDouble(),
        etaMins: (map['etaMins'] as num?)?.toInt(),
        distanceKm: (map['distanceKm'] as num?)?.toDouble(),
        message: map['message'] as String?,
        status: map['status'] as String? ?? 'sent',
        isBestMatch: map['isBestMatch'] as bool? ?? false,
        flaggedSuspicious: map['flaggedSuspicious'] as bool? ?? false,
      );
}
