import 'package:web/web.dart' as web;

/// Appwrite's web client falls back to a `cookieFallback` value in localStorage when the
/// browser won't accept its cross-origin session cookie, and replays it as an
/// `X-Fallback-Cookies` header on every request for the lifetime of the app (see
/// package:appwrite's `client_browser.dart`). It never clears this value itself — not even
/// on logout — so a stale entry from a previous session can outlive that session and get
/// sent alongside a brand-new one, confusing which session Appwrite resolves the request to.
/// Clearing it before starting a fresh login attempt guarantees only the new session's own
/// fallback value (set by the createSession response, if needed) is ever in play.
void clearStaleCookieFallback() {
  web.window.localStorage.removeItem('cookieFallback');
}
