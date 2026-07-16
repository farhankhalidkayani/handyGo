enum UserRole { customer, worker, admin }

UserRole userRoleFromWire(String value) => UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.customer,
    );

/// Mirrors the `users` collection (§5.1).
class UserProfile {
  final String id;
  final String authId;
  final UserRole role;
  final String name;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String language;
  final String status;
  final int riskScore;

  const UserProfile({
    required this.id,
    required this.authId,
    required this.role,
    required this.name,
    this.phone,
    this.email,
    this.photoUrl,
    this.language = 'en',
    this.status = 'active',
    this.riskScore = 0,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['\$id'] as String,
        authId: map['authId'] as String,
        role: userRoleFromWire(map['role'] as String),
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        photoUrl: map['photoUrl'] as String?,
        language: map['language'] as String? ?? 'en',
        status: map['status'] as String? ?? 'active',
        riskScore: (map['riskScore'] as num?)?.toInt() ?? 0,
      );
}
