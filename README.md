# Handy Go

On-demand home-services marketplace — Customer app, Worker app, Admin panel, one real-time
Appwrite backend, zero-cost hybrid AI layer. Full design: [`docs/HandyGo_Development_Plan.md`](docs/HandyGo_Development_Plan.md)
and [`docs/HandyGo_Complete_System_Flow.md`](docs/HandyGo_Complete_System_Flow.md).

This repo currently has **Phase 0** in place: the Appwrite schema, all Appwrite Functions
(AI layer + booking state machine), the shared Dart package, seed data, and all three Flutter
apps scaffolded (`app_customer/`, `app_worker/`, `app_admin/` — each wired to `handygo_shared`,
`dart analyze` clean). Android/iOS builds aren't runnable on this machine yet (no Android SDK or
full Xcode — install Android Studio per `flutter doctor`); web (`flutter run -d chrome`) works
today. No screens beyond the default `flutter create` scaffold exist yet — that's Phase 1.

## Repo layout

```
handyGo/
├── appwrite.json         # declarative schema: 1 database, 15 collections, 12 functions
├── functions/             # Appwrite Functions (Node.js) — the AI layer + state machine guard
│   ├── lib/               # shared aiRouter.js (Ollama/Groq tiered fallback) + appwriteClient.js
│   └── build.js           # copies lib/ into each function's src/lib/ before deploy
├── shared/                # handygo_shared Dart package: BookingStatus enum, models, Appwrite config
├── seed/                  # service_categories + demo accounts (§14.1) + seed.js
├── app_customer/          # Flutter (Android+Web), scaffolded, depends on handygo_shared
├── app_worker/            # Flutter (Android+Web), scaffolded, depends on handygo_shared
├── app_admin/             # Flutter Web, scaffolded, depends on handygo_shared
└── docs/                  # the reference planning docs
```

## 1. Appwrite Cloud project

1. Create a free project at Appwrite Cloud, note the **Project ID**.
2. Create a server API key (Settings → API keys) with scopes: `databases.read`, `databases.write`,
   `users.read`, `users.write`, `functions.read`, `functions.write`.
3. `cp .env.example .env` and fill in `APPWRITE_PROJECT` / `APPWRITE_API_KEY`.

## 2. Push the schema

```bash
npm install -g appwrite-cli
appwrite login
appwrite init project        # point it at the project above; it will read appwrite.json
appwrite push collections    # creates the database + all 15 collections/attributes/indexes
```

## 3. Deploy the Functions

Each function needs the same env vars (`.env.example`) set in the Appwrite Console, or via CLI:

```bash
node functions/build.js      # sync functions/lib into each function's src/lib
appwrite push functions      # deploys all 12 functions from appwrite.json
```

## 4. AI layer (local, $0)

```bash
ollama pull qwen2.5:7b
ollama serve                 # exposes http://localhost:11434 — functions call this as tier 1
```

If Functions run on Appwrite Cloud, `localhost:11434` on your laptop isn't reachable from there —
for the FYP demo, either self-host Appwrite (Docker, see plan §3) so Functions run next to
Ollama, or set `GROQ_API_KEY` in `.env` and unset `OLLAMA_URL` so `aiRouter.js` uses Groq's free
tier as tier 1 instead (same code path, see plan §4.4). Local self-hosted Appwrite is required if
you want to keep AI 100% local/offline.

## 5. Seed demo data

```bash
cd seed && npm install && npm run seed
```

Seeds the 7 service categories (§16.3) plus the demo accounts from plan §14.1 (customer, 4
workers around one area, admin) — password `Handygo@123`.

## 6. Flutter apps

Flutter 3.44.6 is installed and all three apps are scaffolded and analyze clean. To install the
Android toolchain (required to actually run on a device/emulator — currently missing):

```bash
brew install --cask android-studio   # then run it once to install SDK components
flutter doctor --android-licenses
```

Run any app with the endpoint/project as `--dart-define`s, matching `shared/lib/src/appwrite_config.dart`:

```bash
flutter run --dart-define=APPWRITE_PROJECT=handygo --dart-define=APPWRITE_ENDPOINT=https://cloud.appwrite.io/v1
```

## Where to go next

Follow the plan's own phase ordering (§13): build the real-time booking skeleton across the
three apps first (Phases 1–3) before wiring the AI layers on top (Phases 4–8) — the backend here
already supports both.
