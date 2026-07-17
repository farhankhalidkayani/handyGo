# Handy Go

On-demand home-services marketplace — Customer app, Worker app, Admin panel, one real-time
Appwrite backend, zero-cost hybrid AI layer. Full design: [`docs/HandyGo_Development_Plan.md`](docs/HandyGo_Development_Plan.md)
and [`docs/HandyGo_Complete_System_Flow.md`](docs/HandyGo_Complete_System_Flow.md).

This repo currently has **Phase 0** in place and deployed: the Appwrite schema (live on
Appwrite Cloud), both Appwrite Functions (AI layer + booking state machine), the shared Dart
package, seeded demo data, and all three Flutter apps scaffolded (`app_customer/`, `app_worker/`,
`app_admin/` — each wired to `handygo_shared`, `dart analyze` clean). No screens beyond the
default `flutter create` scaffold exist yet — that's Phase 1.

**Functions are consolidated to 2, not 12.** Appwrite Cloud's free tier caps a project at 2
Functions total, discovered while deploying. The plan's 12 conceptual functions (§9.1) are folded
into:
- **`aiRouter`** (HTTP) — dispatches on a `feature` field in the request body: `intake`, `chat`,
  `recommendWorkers`, `workerAssist`, `routePlanner`, `transitionBooking`. Each app call sends
  `{ "feature": "intake", ...payload }`; see `functions/aiRouter/src/handlers/*.js` for each
  feature's logic, unchanged from the plan's single-purpose design.
- **`eventRouter`** (DB events + daily schedule, both on the same function) — dispatches on the
  `x-appwrite-event` header for `messages`/`worker_offers`/`sos_alerts`/`fraud_reports` creates,
  and on `x-appwrite-trigger === 'schedule'` for the daily scoreEngine + analyticsRollup jobs
  (merged into one midnight cron instead of two separately-timed ones — see
  `functions/eventRouter/src/main.js`).

Both are deployed and verified end-to-end against the live project (schema provisioned, demo data
seeded, `aiRouter`'s `intake` feature and `eventRouter`'s event dispatch both tested live).

## Repo layout

```
handyGo/
├── appwrite.json          # declarative schema: 1 database, 15 collections, 2 functions
├── functions/
│   ├── aiRouter/           # HTTP function — src/handlers/{intake,chat,recommendWorkers,workerAssist,routePlanner,transitionBooking}.js
│   ├── eventRouter/        # DB-event + schedule function — src/handlers/{translate,priceGuard,sos,fraud,scoreEngine,analyticsRollup}.js
│   ├── lib/                # shared llm.js (Ollama/Groq tiered fallback), appwriteClient.js, parseBody.js
│   ├── build.js            # copies lib/ into each function's src/lib/ before deploy
│   ├── deploy.js           # idempotent SDK-based deploy (see note below on why not the CLI)
│   └── status.js           # check deployment/build status
├── shared/                 # handygo_shared Dart package: BookingStatus enum, models, Appwrite config
├── seed/                   # service_categories + demo accounts (§14.1), provision.js, seed.js
├── app_customer/           # Flutter (Android+Web), scaffolded, depends on handygo_shared
├── app_worker/             # Flutter (Android+Web), scaffolded, depends on handygo_shared
├── app_admin/              # Flutter Web, scaffolded, depends on handygo_shared
└── docs/                   # the reference planning docs
```

**Why `provision.js`/`deploy.js` instead of the `appwrite` CLI's `push` commands:** the CLI's
interactive confirmation prompts (checkbox pickers, "Type YES to confirm") don't work reliably
over non-TTY/piped input in an agent-driven shell. These scripts do the same job idempotently via
the `node-appwrite` SDK directly — safe to re-run any time schema or function code changes.

## 1. Appwrite Cloud project

1. Create a free project at Appwrite Cloud, note the **Project ID**.
2. Create a server API key (Settings → API keys) with scopes: `databases.read`, `databases.write`,
   `users.read`, `users.write`, `functions.read`, `functions.write`.
3. `cp .env.example .env` and fill in `APPWRITE_PROJECT` / `APPWRITE_API_KEY`.

## 2. Push the schema

```bash
cd seed && npm install
node provision.js   # idempotent: creates whatever's missing, skips what already exists
```

## 3. Deploy the Functions

```bash
cd functions && npm install
node build.js        # sync lib/ into aiRouter/src/lib and eventRouter/src/lib
node deploy.js        # creates/updates both functions, uploads code, sets env vars, activates
node status.js        # check build status of the latest deployment
```

## 4. AI layer (local, $0)

```bash
ollama pull qwen2.5:7b
ollama serve                 # exposes http://localhost:11434 — functions call this as tier 1
```

**Ollama on your laptop is not reachable from Appwrite Cloud** — confirmed in testing; both
functions correctly fall back to rules/canned responses per the fallback ladder (§4.3), but you
won't get real LLM output this way. For actual LLM responses on Appwrite Cloud, set `GROQ_API_KEY`
in `.env` and unset `OLLAMA_URL` so `functions/lib/llm.js` uses Groq's free tier as tier 1 instead
(same code path, see plan §4.4). Self-hosting Appwrite via Docker (see plan §3) is the other option
if you want Functions running next to a local Ollama instance.

## 5. Seed demo data

```bash
cd seed && npm install && npm run seed
```

Seeds the 7 service categories (§16.3) plus the demo accounts from plan §14.1 (customer, 4
workers around one area, admin) — password `Handygo@123`.

## 6. Flutter apps

Flutter 3.44.6 and the Android SDK (headless via `sdkmanager`, no Android Studio GUI needed) are
both installed and working — `flutter doctor` passes, and all three apps build (2 debug APKs, 1
web build).

Run any app with the endpoint/project as `--dart-define`s, matching `shared/lib/src/appwrite_config.dart`:

```bash
flutter run --dart-define=APPWRITE_PROJECT=handygo --dart-define=APPWRITE_ENDPOINT=https://cloud.appwrite.io/v1
```

## 7. Verifying the backend end-to-end

`seed/e2e_test.js` drives the full booking lifecycle (create → offer → select → confirm →
on-the-way → arrived → OTP → in-progress → complete → auto-transaction → rating) as **real
user sessions** (via `users.createSession`, a server-side impersonation endpoint used only for
this test), not the API key — the API key bypasses every permission check, so it's the only way
to actually verify client-side writes/permissions work, not just that the server-side logic is
correct. It also checks the negative cases (customer can't write `bookings.status` directly,
wrong OTP is rejected). Cleans up all its own test data and sessions on exit.

```bash
cd seed && node e2e_test.js
```

## Where to go next

Phases 1 (auth/profiles) and 2 (core booking: create → offers → select → tracking → OTP →
completion → payment → rating, real-time across all 3 apps) are done. Follow the plan's own
phase ordering (§13) for what's next — AI layers (Phases 4–8) on top of this real-time skeleton.
Known follow-ups not yet built: additional-charge approval mid-job, chat, live map/ETA
rendering, cancel/dispute flows, SOS, and photo/voice problem intake.
