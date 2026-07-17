import 'dart:math';

import 'package:appwrite/appwrite.dart';

import 'ai_router_client.dart';
import 'appwrite_config.dart';
import 'booking_status.dart';
import 'models/booking.dart';

/// Booking creation is a direct client write (bookings grants create("users")); every status
/// transition after that goes through the `transitionBooking` aiRouter feature, never a direct
/// client update — see plan §7.1/§11 and functions/aiRouter/src/handlers/transitionBooking.js.
class BookingRepository {
  final Databases databases;
  final AiRouterClient aiRouter;
  final Realtime realtime;

  BookingRepository(Client client)
      : databases = Databases(client),
        aiRouter = AiRouterClient(client),
        realtime = Realtime(client);

  String _generateOtp() => (1000 + Random().nextInt(9000)).toString();

  Future<Booking> createBooking({
    required String customerId,
    required String categoryId,
    required String problemText,
    List<String> problemImages = const [],
    required String addressText,
    required double lat,
    required double lng,
    bool detectedByAi = false,
    double? aiEstimateMin,
    double? aiEstimateMax,
    int? aiDurationMins,
    String? aiUrgency,
    double? aiConfidence,
    String? aiSuggestedSolution,
  }) async {
    final doc = await databases.createDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.bookings,
      documentId: ID.unique(),
      data: {
        'customerId': customerId,
        'categoryId': categoryId,
        'problemText': problemText,
        if (problemImages.isNotEmpty) 'problemImages': problemImages,
        'addressText': addressText,
        'lat': lat,
        'lng': lng,
        'status': BookingStatus.draft.wire,
        'otp': _generateOtp(),
        'detectedByAI': detectedByAi,
        if (aiEstimateMin != null) 'aiEstimateMin': aiEstimateMin,
        if (aiEstimateMax != null) 'aiEstimateMax': aiEstimateMax,
        if (aiDurationMins != null) 'aiDurationMins': aiDurationMins,
        if (aiUrgency != null) 'aiUrgency': aiUrgency,
        if (aiConfidence != null) 'aiConfidence': aiConfidence,
        if (aiSuggestedSolution != null) 'aiSuggestedSolution': aiSuggestedSolution,
      },
      // Explicit empty permissions — Appwrite otherwise grants the creating session
      // implicit owner write access, which would let a customer bypass the state machine
      // and write bookings.status directly (verified against the live project during
      // testing). Read still works for everyone via the collection-level read("users").
      permissions: [],
    );

    await aiRouter.call('transitionBooking', {
      'bookingId': doc.$id,
      'nextStatus': BookingStatus.searchingWorkers.wire,
      'changedByRole': 'customer',
      'changedById': customerId,
    });

    final updated = await databases.getDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.bookings,
      documentId: doc.$id,
    );
    return Booking.fromMap({...updated.data, '\$id': updated.$id});
  }

  Future<Booking> getBooking(String bookingId) async {
    final doc = await databases.getDocument(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.bookings,
      documentId: bookingId,
    );
    return Booking.fromMap({...doc.data, '\$id': doc.$id});
  }

  /// The customer's single active booking, if any (any status that isn't terminal).
  Future<Booking?> findActiveForCustomer(String customerId) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.bookings,
      queries: [
        Query.equal('customerId', customerId),
        Query.notEqual('status', BookingStatus.completed.wire),
        Query.notEqual('status', BookingStatus.cancelled.wire),
        Query.orderDesc('\$createdAt'),
        Query.limit(1),
      ],
    );
    if (res.documents.isEmpty) return null;
    return Booking.fromMap({...res.documents.first.data, '\$id': res.documents.first.$id});
  }

  /// The worker's single active (accepted) job, if any.
  Future<Booking?> findActiveForWorker(String workerUserId) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.bookings,
      queries: [
        Query.equal('workerId', workerUserId),
        Query.notEqual('status', BookingStatus.completed.wire),
        Query.notEqual('status', BookingStatus.cancelled.wire),
        Query.orderDesc('\$createdAt'),
        Query.limit(1),
      ],
    );
    if (res.documents.isEmpty) return null;
    return Booking.fromMap({...res.documents.first.data, '\$id': res.documents.first.$id});
  }

  Future<List<Booking>> listOpenBookings(List<String> categoryIds, {int limit = 50}) async {
    if (categoryIds.isEmpty) return [];
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.bookings,
      queries: [
        Query.equal('status', BookingStatus.searchingWorkers.wire),
        Query.equal('categoryId', categoryIds),
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
      ],
    );
    return res.documents.map((d) => Booking.fromMap({...d.data, '\$id': d.$id})).toList();
  }

  Future<List<Booking>> listAllBookings({int limit = 100}) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.bookings,
      queries: [Query.orderDesc('\$createdAt'), Query.limit(limit)],
    );
    return res.documents.map((d) => Booking.fromMap({...d.data, '\$id': d.$id})).toList();
  }

  Future<Map<String, dynamic>> transition({
    required String bookingId,
    required BookingStatus nextStatus,
    required String changedByRole,
    required String changedById,
    String? note,
    String? otp,
    String? workSummary,
  }) {
    return aiRouter.call('transitionBooking', {
      'bookingId': bookingId,
      'nextStatus': nextStatus.wire,
      'changedByRole': changedByRole,
      'changedById': changedById,
      if (note != null) 'note': note,
      if (otp != null) 'otp': otp,
      if (workSummary != null) 'workSummary': workSummary,
    });
  }

  /// Plan §14.2 demo script: "worker requests Rs. 500 material -> customer approves". The
  /// amount is stored server-side on the booking (pendingAdditionalCharge) rather than
  /// trusted from the client at approval time — see requestAdditionalCharge.js/
  /// approveAdditionalCharge.js for why.
  Future<Map<String, dynamic>> requestAdditionalCharge({
    required String bookingId,
    required String workerId,
    required double amount,
    String? reason,
  }) {
    return aiRouter.call('requestAdditionalCharge', {
      'bookingId': bookingId,
      'workerId': workerId,
      'amount': amount,
      if (reason != null) 'reason': reason,
    });
  }

  Future<Map<String, dynamic>> respondToAdditionalCharge({
    required String bookingId,
    required String customerId,
    required bool approve,
  }) {
    return aiRouter.call('approveAdditionalCharge', {
      'bookingId': bookingId,
      'customerId': customerId,
      'approve': approve,
    });
  }

  /// §9.8: W2/W3/W4 — suggested quote/tools/materials/offer message for a new job, or (mode
  /// "summary") a post-job work summary from job notes + materials (W6). Falls back to a
  /// deterministic mid-band quote / canned summary if the LLM tier is unavailable (see
  /// functions/aiRouter/src/handlers/workerAssist.js).
  Future<Map<String, dynamic>> getWorkerAssist({
    required Booking booking,
    String mode = 'quote',
    List<String>? materials,
    String? jobNotes,
    String language = 'en',
  }) {
    return aiRouter.call('workerAssist', {
      'mode': mode,
      'booking': {'categoryId': booking.categoryId, 'problemText': booking.problemText},
      if (jobNotes != null) 'jobNotes': jobNotes,
      if (materials != null) 'materials': materials,
      'language': language,
    });
  }

  Future<Map<String, dynamic>> selectOffer({
    required String bookingId,
    required String offerId,
    required String customerId,
  }) {
    return aiRouter.call('selectOffer', {
      'bookingId': bookingId,
      'offerId': offerId,
      'customerId': customerId,
    });
  }

  Future<Map<String, dynamic>> submitRating({
    required String bookingId,
    required String customerId,
    required int rating,
    String? reviewText,
  }) {
    return aiRouter.call('submitRating', {
      'bookingId': bookingId,
      'customerId': customerId,
      'rating': rating,
      if (reviewText != null) 'reviewText': reviewText,
    });
  }

  /// §9.3: C2/C3/C4 — rules-first category match, LLM disambiguates if unsure. Never blocks
  /// on the LLM tier (see functions/aiRouter/src/handlers/intake.js) — always returns a
  /// usable category + price band even if the LLM is unreachable.
  Future<Map<String, dynamic>> getAiIntake({
    required String problemText,
    double? lat,
    double? lng,
    String? imageCaption,
  }) {
    return aiRouter.call('intake', {
      'problemText': problemText,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (imageCaption != null) 'imageCaption': imageCaption,
    });
  }

  /// §9.4: C1 — one multilingual chatbot turn.
  Future<Map<String, dynamic>> getAiChatReply({required String message, String? bookingId}) {
    return aiRouter.call('chat', {
      'message': message,
      if (bookingId != null) 'bookingId': bookingId,
    });
  }

  /// Raw realtime channel for the bookings collection — callers filter by bookingId/
  /// customerId/workerId themselves, per the plan's own subscription pattern (§6.2).
  RealtimeSubscription subscribeToBookings() {
    return realtime.subscribe([
      'databases.${HandyGoConfig.databaseId}.collections.${Collections.bookings}.documents',
    ]);
  }
}
