import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import 'stale_session_cleanup.dart';

/// Email-OTP auth shared by all three apps (plan §12: "email OTP" signup/login for every
/// role). `createEmailToken` auto-creates the Appwrite Auth user on first use — there is no
/// separate signup step, just request-OTP then verify-OTP.
class AuthService {
  final Account account;

  AuthService(Client client) : account = Account(client);

  /// Sends a one-time code to [email]. Returns the userId to pass to [verifyOtp] —
  /// the app must hold onto this between the two steps (e.g. in a form's state).
  ///
  /// Clears any stale Appwrite cookie-fallback value left over from a previous session
  /// first (web only — see stale_session_cleanup_web.dart) so it can't get sent alongside
  /// this login's brand-new session and cause the immediately-following `account.get()` to
  /// resolve to the wrong (expired/deleted) session.
  Future<String> requestOtp(String email) async {
    clearStaleCookieFallback();
    final token =
        await account.createEmailToken(userId: ID.unique(), email: email);
    return token.userId;
  }

  /// On native (dart:io) builds, Appwrite's client persists session cookies to disk
  /// (unlike web's in-memory cookie), so a still-valid session from a previous run can
  /// survive even when the app's own routing (e.g. splash screen) incorrectly believes
  /// there's no active session — createSession then fails with "session is active" even
  /// though the OTP itself was correct. Clearing any existing session first (best-effort,
  /// ignored if none exists) makes this call idempotent regardless of that stale state.
  Future<models.Session> verifyOtp(
      {required String userId, required String otp}) async {
    try {
      await account.deleteSession(sessionId: 'current');
    } catch (_) {
      // no active session — nothing to clear
    }
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
