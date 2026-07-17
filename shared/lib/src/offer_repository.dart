import 'package:appwrite/appwrite.dart';

import 'ai_router_client.dart';
import 'appwrite_config.dart';
import 'models/worker_offer.dart';

/// Direct client create (worker_offers grants create("users")) — accepting an offer goes
/// through `BookingRepository.selectOffer` (aiRouter), never a direct client update, since
/// that also has to expire the other offers and set bookings.workerId/status atomically.
class OfferRepository {
  final Databases databases;
  final Realtime realtime;
  final AiRouterClient aiRouter;

  OfferRepository(Client client)
      : databases = Databases(client),
        realtime = Realtime(client),
        aiRouter = AiRouterClient(client);

  Future<WorkerOffer> createOffer({
    required String bookingId,
    required String workerId,
    required double quote,
    int? etaMins,
    double? distanceKm,
    String? message,
  }) async {
    final doc = await databases.createDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.workerOffers,
      documentId: ID.unique(),
      data: {
        'bookingId': bookingId,
        'workerId': workerId,
        'quote': quote,
        'etaMins': etaMins,
        'distanceKm': distanceKm,
        'message': message ?? '',
        'status': 'sent',
      },
      // Explicit empty permissions — see booking_repository.dart for why: otherwise the
      // creating worker gets implicit owner write access and could flip their own offer's
      // status/isBestMatch/flaggedSuspicious directly instead of going through selectOffer.
      permissions: [],
    );
    return WorkerOffer.fromMap({...doc.data, '\$id': doc.$id});
  }

  Future<List<WorkerOffer>> listForBooking(String bookingId) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.workerOffers,
      queries: [Query.equal('bookingId', bookingId), Query.orderAsc('\$createdAt'), Query.limit(50)],
    );
    return res.documents.map((d) => WorkerOffer.fromMap({...d.data, '\$id': d.$id})).toList();
  }

  /// C6 (plan §9.6): recomputes the blended best-match score across every `sent` offer for
  /// this booking and persists `isBestMatch` on the winner. Returns the winning offer ids so
  /// the UI can tag them without a second round trip; safe to call repeatedly (idempotent).
  Future<Map<String, dynamic>> compareOffers(String bookingId) {
    return aiRouter.call('recommendWorkers', {'mode': 'compareOffers', 'bookingId': bookingId});
  }

  RealtimeSubscription subscribeToOffers() {
    return realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.workerOffers}.documents',
    ]);
  }
}
