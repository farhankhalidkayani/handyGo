import 'package:appwrite/appwrite.dart';

import 'ai_router_client.dart';
import 'appwrite_config.dart';
import 'models/fraud_report.dart';

/// Filing a report is a direct client write (fraud_reports grants create("users")) —
/// eventRouter's `fraud` handler fires automatically on create and fills in aiSummary/
/// aiRecommendation server-side (§10.4). adminDecision is only ever set through the
/// admin-gated `updateFraudDecision` aiRouter feature, never a direct client update — AI
/// recommends, admin decides (§8.3).
class FraudRepository {
  final Databases databases;
  final AiRouterClient aiRouter;
  final Realtime realtime;

  FraudRepository(Client client)
      : databases = Databases(client),
        aiRouter = AiRouterClient(client),
        realtime = Realtime(client);

  Future<FraudReport> fileReport({
    required String reportedByRole,
    required String reportedById,
    required String type,
    String? bookingId,
    String? accusedId,
    String? description,
  }) async {
    final doc = await databases.createDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.fraudReports,
      documentId: ID.unique(),
      data: {
        'reportedByRole': reportedByRole,
        'reportedById': reportedById,
        'type': type,
        if (bookingId != null) 'bookingId': bookingId,
        if (accusedId != null) 'accusedId': accusedId,
        'description': description ?? '',
        'status': 'open',
        'adminDecision': 'pending',
      },
      // Explicit empty permissions — same reasoning as every other collection here: the
      // reporter must never be able to edit aiSummary/aiRecommendation/adminDecision later.
      permissions: [],
    );
    return FraudReport.fromMap({...doc.data, '\$id': doc.$id});
  }

  Future<List<FraudReport>> listOpenReports({int limit = 100}) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.fraudReports,
      queries: [
        Query.notEqual('status', 'resolved'),
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
      ],
    );
    return res.documents.map((d) => FraudReport.fromMap({...d.data, '\$id': d.$id})).toList();
  }

  Future<Map<String, dynamic>> updateDecision({
    required String fraudReportId,
    required String adminDecision,
  }) {
    return aiRouter.call('updateFraudDecision', {
      'fraudReportId': fraudReportId,
      'adminDecision': adminDecision,
    });
  }

  RealtimeSubscription subscribeToFraudReports() {
    return realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.fraudReports}.documents',
    ]);
  }
}
