import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';

/// Thin wrapper around calling the `aiRouter` Function's feature-dispatch (§9.1) — every
/// app-invoked feature (intake, chat, transitionBooking, selectOffer, ...) goes through this
/// same call shape, so this exists once instead of being copy-pasted in all three apps.
class AiRouterClient {
  final Functions functions;

  AiRouterClient(Client client) : functions = Functions(client);

  Future<Map<String, dynamic>> call(String feature, Map<String, dynamic> payload) async {
    final execution = await functions.createExecution(
      functionId: 'aiRouter',
      body: jsonEncode({'feature': feature, ...payload}),
      path: '/',
      method: ExecutionMethod.pOST,
      headers: {'content-type': 'application/json'},
    );
    final decoded = execution.responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(execution.responseBody) as Map<String, dynamic>;
    if (execution.responseStatusCode >= 400) {
      throw AiRouterException(decoded['error']?.toString() ?? 'aiRouter call failed', execution.responseStatusCode);
    }
    return decoded;
  }
}

class AiRouterException implements Exception {
  final String message;
  final int statusCode;

  AiRouterException(this.message, this.statusCode);

  @override
  String toString() => message;
}
