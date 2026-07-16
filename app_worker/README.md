# Worker App

Scaffolded with `flutter create` (Android + Web). Depends on `appwrite`, `flutter_map`,
`latlong2`, and the local `handygo_shared` package (path dependency). `dart analyze` is clean.

Android Studio is installed but needs its first-launch SDK setup before Android builds work; web
(`flutter run -d chrome`) works today.

## What to build (plan §12, Worker App checklist)

- Registration (CNIC, selfie, skills, area, docs) → under-review state
- Dashboard (online toggle, earnings, requests, active job, rating, wallet, performance)
- Incoming request card (accept / custom offer / decline) with AI quote + tools suggestion —
  call `aiRouter` with `{ "feature": "workerAssist", "mode": "quote", ... }`
- Navigation (OSM/OSRM route) — call `aiRouter` with `{ "feature": "routePlanner", ... }`, then
  On-the-way / arrived
- OTP entry → service timer → material request → work notes; status writes go through
  `aiRouter` with `{ "feature": "transitionBooking", ... }`, never a direct `bookings` update
  (see plan §11)
- Job completion + AI work summary (`aiRouter` with `{ "feature": "workerAssist", "mode":
  "summary", ... }`) + earnings breakdown
- Safety Center + SOS + Report Fraud

Depends on the same `handygo_shared` package as the Customer app — same `BookingStatus` enum and
`Collections` ids.
