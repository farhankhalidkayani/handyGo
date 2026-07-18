import 'package:appwrite/appwrite.dart';

import 'appwrite_config.dart';
import 'models/call.dart';

/// WebRTC signaling (plan's masked-calling requirement, satisfied for the "no number shown
/// pre-acceptance" part elsewhere — this is the zero-cost alternative to real telephony-level
/// masking, which needs a paid proxy service). Every doc/candidate is a direct client
/// create/read — this is call *setup* metadata (SDP/ICE), not the call audio itself, which
/// flows peer-to-peer once connected. `calls` also grants collection-level `update("users")`
/// (verified live: without it, the callee gets a 401 answering — Appwrite only grants the
/// *creator* implicit update rights, and the callee never creates the doc). Unlike bookings/
/// transactions, this is low-sensitivity — no money or state-machine implications — so a
/// blanket update is an acceptable tradeoff against the complexity of resolving the peer's
/// real Auth id client-side just to scope it per-document.
class CallRepository {
  final Databases databases;
  final Realtime realtime;

  CallRepository(Client client)
      : databases = Databases(client),
        realtime = Realtime(client);

  Future<Call> createCall({
    required String bookingId,
    required String callerId,
    required String calleeId,
    required String callerRole,
    required String offerSdp,
  }) async {
    final doc = await databases.createDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.calls,
      documentId: ID.unique(),
      data: {
        'bookingId': bookingId,
        'callerId': callerId,
        'calleeId': calleeId,
        'callerRole': callerRole,
        'status': 'ringing',
        'offerSdp': offerSdp,
      },
    );
    return Call.fromMap({...doc.data, '\$id': doc.$id});
  }

  Future<void> answerCall({required String callId, required String answerSdp}) {
    return databases.updateDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.calls,
      documentId: callId,
      data: {'status': 'accepted', 'answerSdp': answerSdp},
    );
  }

  Future<void> updateStatus({required String callId, required String status}) {
    return databases.updateDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.calls,
      documentId: callId,
      data: {'status': status},
    );
  }

  Future<void> sendCandidate({
    required String callId,
    required String senderId,
    required String candidate,
  }) {
    return databases.createDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.callCandidates,
      documentId: ID.unique(),
      data: {'callId': callId, 'senderId': senderId, 'candidate': candidate},
    );
  }

  Future<List<Map<String, dynamic>>> listCandidates(String callId, {String? excludeSenderId}) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.callCandidates,
      queries: [Query.equal('callId', callId), Query.limit(200)],
    );
    return res.documents
        .where((d) => excludeSenderId == null || d.data['senderId'] != excludeSenderId)
        .map((d) => d.data)
        .toList();
  }

  /// Incoming-call listener — subscribed while the active job / tracking screen is open.
  RealtimeSubscription subscribeToCalls() {
    return realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.calls}.documents',
    ]);
  }

  RealtimeSubscription subscribeToCandidates() {
    return realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.callCandidates}.documents',
    ]);
  }
}
