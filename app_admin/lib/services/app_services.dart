import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:handygo_shared/handygo_shared.dart';

/// Single shared Appwrite client + service instances for the Admin Panel.
class AppServices {
  AppServices._();

  static final Client client = HandyGoConfig.buildClient();
  static final AuthService auth = AuthService(client);
  static final ProfileRepository profiles = ProfileRepository(client);
  static final Databases databases = Databases(client);
  static final Functions functions = Functions(client);

  /// Calls the `aiRouter` Function's `updateWorkerVerification` feature (admin-gated
  /// server-side via the caller's real Appwrite user id — see
  /// functions/aiRouter/src/handlers/updateWorkerVerification.js).
  static Future<Map<String, dynamic>> updateWorkerVerification({
    required String workerProfileId,
    required String status,
    String? reason,
  }) async {
    final execution = await functions.createExecution(
      functionId: 'aiRouter',
      body: jsonEncode({
        'feature': 'updateWorkerVerification',
        'workerProfileId': workerProfileId,
        'status': status,
        if (reason != null) 'reason': reason,
      }),
      path: '/',
      method: ExecutionMethod.pOST,
      headers: {'content-type': 'application/json'},
    );
    final decoded = jsonDecode(execution.responseBody) as Map<String, dynamic>;
    if (execution.responseStatusCode >= 400) {
      throw Exception(decoded['error'] ?? 'updateWorkerVerification failed');
    }
    return decoded;
  }
}
