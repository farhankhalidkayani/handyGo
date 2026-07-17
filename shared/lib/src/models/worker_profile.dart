/// Mirrors the `worker_profiles` collection (§5.3).
class WorkerProfile {
  final String id;
  final String userId;
  final List<String> skills;
  final String verificationStatus;
  final String availability;
  final double rating;
  final int jobsCompleted;
  final double? currentLat;
  final double? currentLng;
  final double walletBalance;
  final double pendingBalance;
  final int performanceScore;
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final String? selfieUrl;

  const WorkerProfile({
    required this.id,
    required this.userId,
    required this.skills,
    required this.verificationStatus,
    required this.availability,
    required this.rating,
    required this.jobsCompleted,
    this.currentLat,
    this.currentLng,
    this.walletBalance = 0,
    this.pendingBalance = 0,
    this.performanceScore = 50,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.selfieUrl,
  });

  factory WorkerProfile.fromMap(Map<String, dynamic> map) => WorkerProfile(
        id: map['\$id'] as String,
        userId: map['userId'] as String,
        skills: (map['skills'] as List?)?.cast<String>() ?? const [],
        verificationStatus: map['verificationStatus'] as String? ?? 'incomplete',
        availability: map['availability'] as String? ?? 'offline',
        rating: (map['rating'] as num?)?.toDouble() ?? 0,
        jobsCompleted: (map['jobsCompleted'] as num?)?.toInt() ?? 0,
        currentLat: (map['currentLat'] as num?)?.toDouble(),
        currentLng: (map['currentLng'] as num?)?.toDouble(),
        walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0,
        pendingBalance: (map['pendingBalance'] as num?)?.toDouble() ?? 0,
        performanceScore: (map['performanceScore'] as num?)?.toInt() ?? 50,
        cnicFrontUrl: map['cnicFrontUrl'] as String?,
        cnicBackUrl: map['cnicBackUrl'] as String?,
        selfieUrl: map['selfieUrl'] as String?,
      );
}
