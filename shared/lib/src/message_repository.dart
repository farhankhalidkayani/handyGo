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

  /// [threadWorkerId] scopes this message to one worker's private pre-offer thread with the
  /// customer (plan's "ask a question before offering") — without it, multiple workers
  /// messaging the same open booking would land in one unattributed, jumbled thread. Leave
  /// null for the normal active-job chat, which is already inherently 1:1 once a worker is
  /// assigned.
  Future<Message> sendMessage({
    required String bookingId,
    required String senderId,
    required String senderRole,
    required String text,
    String? threadWorkerId,
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
        if (threadWorkerId != null) 'threadWorkerId': threadWorkerId,
      },
      permissions: [],
    );
    return Message.fromMap({...doc.data, '\$id': doc.$id});
  }

  /// [threadWorkerId] null = the main active-job chat (messages with no thread set);
  /// non-null = one specific worker's pre-offer thread.
  Future<List<Message>> listForBooking(String bookingId, {String? threadWorkerId}) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.messages,
      queries: [
        Query.equal('bookingId', bookingId),
        threadWorkerId != null ? Query.equal('threadWorkerId', threadWorkerId) : Query.isNull('threadWorkerId'),
        Query.orderAsc('\$createdAt'),
        Query.limit(200),
      ],
    );
    return res.documents.map((d) => Message.fromMap({...d.data, '\$id': d.$id})).toList();
  }

  /// Customer's "questions from workers" inbox (plan's pre-offer ask flow) — every distinct
  /// worker who has messaged this booking before an offer was accepted.
  Future<List<String>> listPreOfferThreadWorkerIds(String bookingId) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.messages,
      queries: [
        Query.equal('bookingId', bookingId),
        Query.isNotNull('threadWorkerId'),
        Query.limit(200),
      ],
    );
    return res.documents.map((d) => d.data['threadWorkerId'] as String).toSet().toList();
  }

  /// Admin AI insights (plan §12 "chat-scan flags") — messages eventRouter's `translate`
  /// handler flagged for external-payment/abuse language (§9.5), most recent first.
  Future<List<Message>> listFlagged({int limit = 50}) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.messages,
      queries: [Query.equal('aiFlagged', true), Query.orderDesc('\$createdAt'), Query.limit(limit)],
    );
    return res.documents.map((d) => Message.fromMap({...d.data, '\$id': d.$id})).toList();
  }

  RealtimeSubscription subscribeToMessages() {
    return realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.messages}.documents',
    ]);
  }
}
