/// Mirrors the `sos_alerts` collection (§5.12, §10). `aiRiskLevel` always comes from the
/// rules tier in `sosProcessor` — see the design note in the plan §9.9.
class SosAlert {
  final String id;
  final String? bookingId;
  final String raisedByRole;
  final String raisedById;
  final String? counterpartId;
  final String emergencyType;
  final double? lat;
  final double? lng;
  final String? aiRiskLevel;
  final String? aiSummary;
  final List<String> aiSuggestedActions;
  final String adminStatus;

  const SosAlert({
    required this.id,
    this.bookingId,
    required this.raisedByRole,
    required this.raisedById,
    this.counterpartId,
    required this.emergencyType,
    this.lat,
    this.lng,
    this.aiRiskLevel,
    this.aiSummary,
    this.aiSuggestedActions = const [],
    this.adminStatus = 'open',
  });

  factory SosAlert.fromMap(Map<String, dynamic> map) => SosAlert(
        id: map['\$id'] as String,
        bookingId: map['bookingId'] as String?,
        raisedByRole: map['raisedByRole'] as String,
        raisedById: map['raisedById'] as String,
        counterpartId: map['counterpartId'] as String?,
        emergencyType: map['emergencyType'] as String,
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
        aiRiskLevel: map['aiRiskLevel'] as String?,
        aiSummary: map['aiSummary'] as String?,
        aiSuggestedActions: (map['aiSuggestedActions'] as List?)?.cast<String>() ?? const [],
        adminStatus: map['adminStatus'] as String? ?? 'open',
      );
}
