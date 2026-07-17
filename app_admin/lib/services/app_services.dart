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

  /// Calls the `aiRouter` Function's `updateWorkerVerification` feature (admin-gated
  /// server-side via the caller's real Appwrite user id — see
  /// functions/aiRouter/src/handlers/updateWorkerVerification.js).
  static Future<Map<String, dynamic>> updateWorkerVerification({
    required String workerProfileId,
    required String status,
    String? reason,
  }) {
    return aiRouter.call('updateWorkerVerification', {
      'workerProfileId': workerProfileId,
      'status': status,
      if (reason != null) 'reason': reason,
    });
  }
}
