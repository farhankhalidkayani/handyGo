import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import 'ai_router_client.dart';
import 'appwrite_config.dart';
import 'models/user_profile.dart';
import 'models/worker_profile.dart';

/// Reads/writes the `users` document (and role-specific profile) tied to the current Auth
/// user. A brand-new Auth user (first OTP login ever) has no `users` document yet — that's
/// how the apps decide whether to show profile setup vs. go straight home.
class ProfileRepository {
  final Databases databases;
  final AiRouterClient aiRouter;
  final Realtime realtime;

  ProfileRepository(Client client)
      : databases = Databases(client),
        aiRouter = AiRouterClient(client),
        realtime = Realtime(client);

  Future<UserProfile?> findByAuthId(String authId) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.users,
      queries: [Query.equal('authId', authId), Query.limit(1)],
    );
    if (res.documents.isEmpty) return null;
    return UserProfile.fromMap(
        res.documents.first.data..addAll({'\$id': res.documents.first.$id}));
  }

  Future<UserProfile?> findById(String userId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: HandyGoConfig.databaseId,
        collectionId: Collections.users,
        documentId: userId,
      );
      return UserProfile.fromMap({...doc.data, '\$id': doc.$id});
    } catch (_) {
      return null;
    }
  }

  /// Documents get owner-only write permission (in addition to the broad collection-level
  /// read) so e.g. a worker can toggle their own availability directly from the client —
  /// everything else (status transitions, verification, scores) still only writable via the
  /// API-key-backed Functions, per §11.
  List<String> _ownerPermissions(String authId) =>
      [Permission.write(Role.user(authId))];

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
      permissions: _ownerPermissions(authId),
    );
  }

  Future<models.Document> createCustomerProfile({
    required String authId,
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
      permissions: _ownerPermissions(authId),
    );
  }

  Future<models.Document> createWorkerProfile({
    required String authId,
    required String userId,
    required List<String> skills,
    required double serviceAreaLat,
    required double serviceAreaLng,
    double serviceRadiusKm = 8,
    int experienceYears = 0,
    String? cnicFrontUrl,
    String? cnicBackUrl,
    String? selfieUrl,
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
        if (cnicFrontUrl != null) 'cnicFrontUrl': cnicFrontUrl,
        if (cnicBackUrl != null) 'cnicBackUrl': cnicBackUrl,
        if (selfieUrl != null) 'selfieUrl': selfieUrl,
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
      permissions: _ownerPermissions(authId),
    );
  }

  Future<models.Document> updateWorkerAvailability({
    required String workerProfileId,
    required String availability,
  }) {
    return databases.updateDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.workerProfiles,
      documentId: workerProfileId,
      data: {'availability': availability},
    );
  }

  /// Best-effort location ping — lets the customer's tracking screen show roughly where the
  /// worker is. Not a continuous live-tracking feed (would need a background location service);
  /// updated opportunistically whenever the worker app already fetches a GPS fix for ETA.
  Future<void> updateWorkerLocation({
    required String workerProfileId,
    required double lat,
    required double lng,
  }) {
    return databases.updateDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.workerProfiles,
      documentId: workerProfileId,
      data: {'currentLat': lat, 'currentLng': lng},
    );
  }

  /// Zeroes the worker's `walletBalance` server-side (plan §12 "Wallet + withdraw") — see
  /// functions/aiRouter/src/handlers/withdrawWallet.js for why this can't be a direct client
  /// update (walletBalance is server-only, only ever credited on booking completion).
  Future<Map<String, dynamic>> withdrawWallet(String workerProfileId) {
    return aiRouter
        .call('withdrawWallet', {'workerProfileId': workerProfileId});
  }

  /// Plan §12 Worker checklist "AI performance tips" — see workerAssist.js's `performanceTips`
  /// mode (rules-first for clear-cut scores, LLM only for the mixed middle range).
  Future<Map<String, dynamic>> getPerformanceTip(WorkerProfile worker) {
    return aiRouter.call('workerAssist', {
      'mode': 'performanceTips',
      'rating': worker.rating,
      'jobsCompleted': worker.jobsCompleted,
      'performanceScore': worker.performanceScore,
    });
  }

  Future<WorkerProfile?> findWorkerProfileByUserId(String userId) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.workerProfiles,
      queries: [Query.equal('userId', userId), Query.limit(1)],
    );
    if (res.documents.isEmpty) return null;
    return WorkerProfile.fromMap(
        {...res.documents.first.data, '\$id': res.documents.first.$id});
  }

  /// Raw realtime channel for the worker_profiles collection — callers filter by workerId/
  /// verificationStatus themselves, same pattern as BookingRepository.subscribeToBookings.
  RealtimeSubscription subscribeToWorkerProfiles() {
    return realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.workerProfiles}.documents',
    ]);
  }
}
