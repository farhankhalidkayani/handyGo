import 'package:appwrite/appwrite.dart';

import 'ai_router_client.dart';
import 'appwrite_config.dart';
import 'models/app_notification.dart';

/// Notifications are created server-side across many handlers (offer accepted, verification
/// decisions, SOS, fraud, charge approvals, ...) without owner permissions set — marking one
/// read goes through the admin/self-gated `markNotificationRead` aiRouter feature rather than
/// a direct client update. Admin notifications use the literal `userId: "admin"` sentinel
/// (a shared inbox for every admin), not a specific admin's own id.
class NotificationRepository {
  final Databases databases;
  final AiRouterClient aiRouter;
  final Realtime realtime;

  NotificationRepository(Client client)
      : databases = Databases(client),
        aiRouter = AiRouterClient(client),
        realtime = Realtime(client);

  Future<List<AppNotification>> listForUser(String userId, {int limit = 100}) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.notifications,
      queries: [
        Query.equal('userId', userId),
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
      ],
    );
    return res.documents.map((d) => AppNotification.fromMap({...d.data, '\$id': d.$id})).toList();
  }

  Future<Map<String, dynamic>> markRead(String notificationId) {
    return aiRouter.call('markNotificationRead', {'notificationId': notificationId});
  }

  RealtimeSubscription subscribeToNotifications() {
    return realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.notifications}.documents',
    ]);
  }
}
