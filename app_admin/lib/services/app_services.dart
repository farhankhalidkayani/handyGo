import 'package:appwrite/appwrite.dart';
import 'package:handygo_shared/handygo_shared.dart';

/// Single shared Appwrite client + service instances for the Admin Panel.
class AppServices {
  AppServices._();

  static final Client client = HandyGoConfig.buildClient();
  static final AuthService auth = AuthService(client);
  static final ProfileRepository profiles = ProfileRepository(client);
  static final Databases databases = Databases(client);
  static final AiRouterClient aiRouter = AiRouterClient(client);
  static final BookingRepository bookings = BookingRepository(client);
  static final SosRepository sos = SosRepository(client);
  static final FraudRepository fraud = FraudRepository(client);
  static final NotificationRepository notifications = NotificationRepository(client);
  static final CategoryRepository categories = CategoryRepository(client);
  static final TransactionRepository transactions = TransactionRepository(client);
  static final MessageRepository messages = MessageRepository(client);
  static final MediaRepository media = MediaRepository(client);

  /// Calls the `aiRouter` Function's `updateWorkerVerification` feature (admin-gated
  /// server-side via the caller's real Appwrite user id — see
  /// functions/aiRouter/src/handlers/updateWorkerVerification.js).
  static Future<Map<String, dynamic>> updateWorkerVerification({
    required String workerProfileId,
    String? status,
    String? reason,
    bool requestMoreInfo = false,
  }) {
    return aiRouter.call('updateWorkerVerification', {
      'workerProfileId': workerProfileId,
      if (status != null) 'status': status,
      if (reason != null) 'reason': reason,
      if (requestMoreInfo) 'requestMoreInfo': true,
    });
  }

  /// See functions/aiRouter/src/handlers/reassignWorker.js.
  static Future<Map<String, dynamic>> reassignWorker({
    required String bookingId,
    required String newWorkerId,
    String? reason,
  }) {
    return aiRouter.call('reassignWorker', {
      'bookingId': bookingId,
      'newWorkerId': newWorkerId,
      if (reason != null) 'reason': reason,
    });
  }

  /// See functions/aiRouter/src/handlers/applyPenalty.js.
  static Future<Map<String, dynamic>> applyPenalty({
    required String bookingId,
    required String userId,
    required String reason,
    int points = 10,
  }) {
    return aiRouter.call('applyPenalty', {
      'bookingId': bookingId,
      'userId': userId,
      'reason': reason,
      'points': points,
    });
  }
}
