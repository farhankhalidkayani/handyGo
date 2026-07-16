# Customer App

Scaffolded with `flutter create` (Android + Web). Depends on `appwrite`, `flutter_map`,
`latlong2`, and the local `handygo_shared` package (path dependency). `dart analyze` is clean.

Android/iOS builds aren't runnable yet on this machine — no Android SDK or full Xcode installed
(`flutter doctor` flags both). Web (`flutter run -d chrome`) works today. Install Android Studio
to build/run on Android, per `flutter doctor`'s instructions.

## What to build (plan §12, Customer App checklist)

- Splash → language select → location permission → login/signup → email OTP → profile setup → home
- Home: search, AI Assistant button, categories, active-booking card
- Service request: manual / AI chatbot / image — all writing to `bookings` (never call AI
  providers directly from the app — go through the `aiIntake`/`aiChat` Functions)
- AI estimate card, offers screen (best price/fastest/top rated/best match), live tracking (OSM),
  OTP display, completion → payment → rating, Safety Center + SOS + Report Fraud

Use `handygo_shared`'s `BookingStatus` enum and `Collections` ids — never hard-code status
strings or collection names; they must match `appwrite.json` exactly.
