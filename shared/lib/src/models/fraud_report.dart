/// Mirrors the `fraud_reports` collection (§5.13, §10.4). `aiSummary`/`aiRecommendation` are
/// written server-side by eventRouter's `fraud` handler; `adminDecision` is only ever set by
/// the admin-gated `updateFraudDecision` aiRouter feature — AI never decides, only recommends
/// (§8.3 governance rule).
class FraudReport {
  final String id;
  final String? bookingId;
  final String reportedByRole;
  final String reportedById;
  final String? accusedId;
  final String type;
  final String? description;
  final String? aiSummary;
  final String? aiRecommendation;
  final String adminDecision;
  final String status;

  const FraudReport({
    required this.id,
    this.bookingId,
    required this.reportedByRole,
    required this.reportedById,
    this.accusedId,
    required this.type,
    this.description,
    this.aiSummary,
    this.aiRecommendation,
    this.adminDecision = 'pending',
    this.status = 'open',
  });

  factory FraudReport.fromMap(Map<String, dynamic> map) => FraudReport(
        id: map['\$id'] as String,
        bookingId: map['bookingId'] as String?,
        reportedByRole: map['reportedByRole'] as String,
        reportedById: map['reportedById'] as String,
        accusedId: map['accusedId'] as String?,
        type: map['type'] as String,
        description: map['description'] as String?,
        aiSummary: map['aiSummary'] as String?,
        aiRecommendation: map['aiRecommendation'] as String?,
        adminDecision: map['adminDecision'] as String? ?? 'pending',
        status: map['status'] as String? ?? 'open',
      );
}
