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
      );
}
