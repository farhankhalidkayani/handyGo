import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

/// Email-OTP auth shared by all three apps (plan §12: "email OTP" signup/login for every
/// role). `createEmailToken` auto-creates the Appwrite Auth user on first use — there is no
/// separate signup step, just request-OTP then verify-OTP.
class AuthService {
  final Account account;

  AuthService(Client client) : account = Account(client);

  /// Sends a one-time code to [email]. Returns the userId to pass to [verifyOtp] —
  /// the app must hold onto this between the two steps (e.g. in a form's state).
  Future<String> requestOtp(String email) async {
    final token = await account.createEmailToken(userId: ID.unique(), email: email);
    return token.userId;
  }

  Future<models.Session> verifyOtp({required String userId, required String otp}) {
    return account.createSession(userId: userId, secret: otp);
  }

  Future<models.User?> getCurrentUser() async {
    try {
      return await account.get();
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await account.deleteSession(sessionId: 'current');
    } catch (_) {
      // no active session — nothing to do
    }
  }
}
