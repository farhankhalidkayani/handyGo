import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import 'appwrite_config.dart';
import 'models/user_profile.dart';
import 'models/worker_profile.dart';

/// Reads/writes the `users` document (and role-specific profile) tied to the current Auth
/// user. A brand-new Auth user (first OTP login ever) has no `users` document yet — that's
/// how the apps decide whether to show profile setup vs. go straight home.
class ProfileRepository {
  final Databases databases;

  ProfileRepository(Client client) : databases = Databases(client);

  Future<UserProfile?> findByAuthId(String authId) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.users,
      queries: [Query.equal('authId', authId), Query.limit(1)],
    );
    if (res.documents.isEmpty) return null;
    return UserProfile.fromMap(res.documents.first.data..addAll({'\$id': res.documents.first.$id}));
  }

  Future<models.Document> createUserDocument({
    required String authId,
    required String role,
    required String name,
    String? email,
    String? phone,
    String language = 'en',
  }) {
    return databases.createDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.users,
      documentId: ID.unique(),
      data: {
        'authId': authId,
        'role': role,
        'name': name,
        'email': email ?? '',
        'phone': phone ?? '',
        'language': language,
        'status': 'active',
        'riskScore': 0,
        'createdVia': 'app',
      },
    );
  }

  Future<models.Document> createCustomerProfile({
    required String userId,
    double? lat,
    double? lng,
    String? defaultAddress,
  }) {
    return databases.createDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.customerProfiles,
      documentId: ID.unique(),
      data: {
        'userId': userId,
        'currentLat': lat,
        'currentLng': lng,
        'defaultAddress': defaultAddress ?? '',
        'totalBookings': 0,
        'trustScore': 100,
      },
    );
  }

  Future<models.Document> createWorkerProfile({
    required String userId,
    required List<String> skills,
    required double serviceAreaLat,
    required double serviceAreaLng,
    double serviceRadiusKm = 8,
    int experienceYears = 0,
  }) {
    return databases.createDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.workerProfiles,
      documentId: ID.unique(),
      data: {
        'userId': userId,
        'skills': skills,
        'experienceYears': experienceYears,
        'serviceAreaLat': serviceAreaLat,
        'serviceAreaLng': serviceAreaLng,
        'serviceRadiusKm': serviceRadiusKm,
        'verificationStatus': 'under_review',
        'availability': 'offline',
        'rating': 0,
        'jobsCompleted': 0,
        'walletBalance': 0,
        'pendingBalance': 0,
        'performanceScore': 50,
        'currentLat': serviceAreaLat,
        'currentLng': serviceAreaLng,
      },
    );
  }

  Future<WorkerProfile?> findWorkerProfileByUserId(String userId) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.workerProfiles,
      queries: [Query.equal('userId', userId), Query.limit(1)],
    );
    if (res.documents.isEmpty) return null;
    return WorkerProfile.fromMap({...res.documents.first.data, '\$id': res.documents.first.$id});
  }
}
