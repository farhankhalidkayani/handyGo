import 'package:appwrite/appwrite.dart';

import 'appwrite_config.dart';
import 'models/message.dart';

/// Direct client create (messages grants create("users")) — eventRouter's `translate` handler
/// fires automatically on create and fills in translatedText/aiFlagged server-side (§9.5).
/// Explicit empty permissions on create for the same reason as bookings/worker_offers: avoid
/// the implicit-owner-write default so a sender can't edit aiFlagged/translatedText after the
/// fact (verified as a real gap earlier — see booking_repository.dart's comment).
class MessageRepository {
  final Databases databases;
  final Realtime realtime;

  MessageRepository(Client client)
      : databases = Databases(client),
        realtime = Realtime(client);

  Future<Message> sendMessage({
    required String bookingId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    final doc = await databases.createDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.messages,
      documentId: ID.unique(),
      data: {
        'bookingId': bookingId,
        'senderId': senderId,
        'senderRole': senderRole,
        'text': text,
      },
      permissions: [],
    );
    return Message.fromMap({...doc.data, '\$id': doc.$id});
  }

  Future<List<Message>> listForBooking(String bookingId) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.messages,
      queries: [Query.equal('bookingId', bookingId), Query.orderAsc('\$createdAt'), Query.limit(200)],
    );
    return res.documents.map((d) => Message.fromMap({...d.data, '\$id': d.$id})).toList();
  }

  RealtimeSubscription subscribeToMessages() {
    return realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.messages}.documents',
    ]);
  }
}
