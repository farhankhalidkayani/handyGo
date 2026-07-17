import 'package:appwrite/appwrite.dart';

import 'ai_router_client.dart';
import 'appwrite_config.dart';
import 'models/sos_alert.dart';

/// Raising an alert is a direct client write (sos_alerts grants create("users")) — the risk
/// level/summary/actions are filled in server-side by eventRouter's `sos` handler (§9.9),
/// which always fires immediately regardless of the LLM tier (rules-based risk level first).
/// adminStatus/timeline updates go through the admin-gated `updateSosStatus` aiRouter feature
/// (§10.3), same pattern as updateWorkerVerification — never a direct client update.
class SosRepository {
  final Databases databases;
  final AiRouterClient aiRouter;
  final Realtime realtime;

  SosRepository(Client client)
      : databases = Databases(client),
        aiRouter = AiRouterClient(client),
        realtime = Realtime(client);

  Future<SosAlert> raiseAlert({
    required String raisedByRole,
    required String raisedById,
    required String emergencyType,
    String? bookingId,
    String? counterpartId,
    double? lat,
    double? lng,
    String? deviceInfo,
  }) async {
    final doc = await databases.createDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.sosAlerts,
      documentId: ID.unique(),
      data: {
        'raisedByRole': raisedByRole,
        'raisedById': raisedById,
        'emergencyType': emergencyType,
        if (bookingId != null) 'bookingId': bookingId,
        if (counterpartId != null) 'counterpartId': counterpartId,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'deviceInfo': deviceInfo ?? '',
        'adminStatus': 'open',
      },
      // Explicit empty permissions — same reasoning as bookings/worker_offers/messages: an
      // SOS report must never be editable by the person who raised it.
      permissions: [],
    );
    return SosAlert.fromMap({...doc.data, '\$id': doc.$id});
  }

  Future<List<SosAlert>> listOpenAlerts({int limit = 100}) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.sosAlerts,
      queries: [
        Query.notEqual('adminStatus', 'closed'),
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
      ],
    );
    return res.documents.map((d) => SosAlert.fromMap({...d.data, '\$id': d.$id})).toList();
  }

  Future<Map<String, dynamic>> updateStatus({
    required String sosAlertId,
    required String adminStatus,
    String? action,
    String? suspendUserId,
    String? bookingAction,
  }) {
    return aiRouter.call('updateSosStatus', {
      'sosAlertId': sosAlertId,
      'adminStatus': adminStatus,
      if (action != null) 'action': action,
      if (suspendUserId != null) 'suspendUserId': suspendUserId,
      if (bookingAction != null) 'bookingAction': bookingAction,
    });
  }

  RealtimeSubscription subscribeToSosAlerts() {
    return realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.sosAlerts}.documents',
    ]);
  }
}
