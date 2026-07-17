import '../booking_status.dart';

/// Mirrors the `bookings` collection (§5.5). `status` is server-authoritative — clients
/// only ever read it; writes go through the `transitionBooking` Function (§7.1, §11).
class Booking {
  final String id;
  final String customerId;
  final String? workerId;
  final String categoryId;
  final bool detectedByAi;
  final String problemText;
  final String addressText;
  final double lat;
  final double lng;
  final double? aiEstimateMin;
  final double? aiEstimateMax;
  final String aiUrgency;
  final double? finalQuote;
  final BookingStatus status;
  final String? otp;
  final int? ratingGiven;
  final String? reviewText;

  const Booking({
    required this.id,
    required this.customerId,
    this.workerId,
    required this.categoryId,
    this.detectedByAi = false,
    required this.problemText,
    this.addressText = '',
    required this.lat,
    required this.lng,
    this.aiEstimateMin,
    this.aiEstimateMax,
    this.aiUrgency = 'normal',
    this.finalQuote,
    required this.status,
    this.otp,
    this.ratingGiven,
    this.reviewText,
  });

  factory Booking.fromMap(Map<String, dynamic> map) => Booking(
        id: map['\$id'] as String,
        customerId: map['customerId'] as String,
        workerId: map['workerId'] as String?,
        categoryId: map['categoryId'] as String,
        detectedByAi: map['detectedByAI'] as bool? ?? false,
        problemText: map['problemText'] as String? ?? '',
        addressText: map['addressText'] as String? ?? '',
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        aiEstimateMin: (map['aiEstimateMin'] as num?)?.toDouble(),
        aiEstimateMax: (map['aiEstimateMax'] as num?)?.toDouble(),
        aiUrgency: map['aiUrgency'] as String? ?? 'normal',
        finalQuote: (map['finalQuote'] as num?)?.toDouble(),
        status: BookingStatusWire.fromWire(map['status'] as String),
        otp: map['otp'] as String?,
        ratingGiven: (map['ratingGiven'] as num?)?.toInt(),
        reviewText: map['reviewText'] as String?,
      );
}
