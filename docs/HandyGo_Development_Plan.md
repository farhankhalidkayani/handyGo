# Handy Go — Full Development Plan (Customer + Worker + Admin, AI-Powered, Real-Time)

**Project type:** Final Year Project (FYP) — professional real-world home-services marketplace
**Deliverable:** 3 connected apps + real-time Appwrite backend + zero-cost AI layer
**Version:** 1.0 · **Date:** 16 July 2026

> Ye plan aapke do reference documents (Final Documentation + Complete System Flow) ko ek executable engineering roadmap mein convert karta hai. Har AI feature, database collection, real-time channel, code sample, aur build phase yahan defined hai. Sab data **real backend + Appwrite collections** se aayega — koi dummy/static screen nahi.

---

## Table of Contents

1. Goals & Non-Negotiables
2. High-Level Architecture
3. Zero-Cost Technology Stack (FYP-optimised)
4. Zero-Cost AI Strategy (the key decision)
5. Appwrite Backend — Complete Schema (all collections)
6. Real-Time Sync Design (channels & listeners)
7. Booking State Machine (shared across 3 apps)
8. AI Feature Specifications (Customer / Worker / Admin)
9. AI Implementation — Prompts, Functions & Code
10. Safety System (SOS + Fraud) Implementation
11. Security, Roles & Permissions
12. Screen-by-Screen Build Checklist
13. Development Phases & Timeline (12 weeks)
14. Testing, Demo Mode & FYP Presentation
15. Risk Register & Fallbacks
16. Appendix: Env vars, folder structure, seed data

---

## 1. Goals & Non-Negotiables

**Primary goal:** Ek Careem/InDrive-style on-demand home-services marketplace jisme Customer App, Worker App aur Admin Panel real-time connected hon, aur AI har layer par intelligent decisions suggest kare (but final action human/admin ke paas rahe).

**Non-negotiables (in scope, must work end-to-end):**

- Teeno apps ek hi Appwrite backend se connected — same collections, same status names.
- Har booking status, offer, message, notification, location, payment, SOS aur fraud report **real-time** teeno apps mein update ho.
- AI multilingual (Urdu, English, Roman Urdu) samjhe aur reply kare.
- AI sirf **recommendation + alert** de; final decision admin/user kare.
- Zero recurring cost (FYP budget = 0). Paid APIs optional/future-scope.
- No dummy data: every screen reads/writes live Appwrite documents.

**Explicitly out-of-scope for FYP demo (future scope):** real online-payment gateway settlement, iOS App Store release, production-grade load, real emergency-services dispatch integration.

---

## 2. High-Level Architecture

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Customer App │   │  Worker App  │   │ Admin Panel  │
│  (Flutter)   │   │  (Flutter)   │   │  (Flutter    │
│              │   │              │   │   Web/React) │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │
       │   Appwrite SDK (Realtime + REST)    │
       └──────────────────┼──────────────────┘
                          │
              ┌───────────▼────────────┐
              │       APPWRITE          │
              │  Auth · Databases       │
              │  Realtime · Storage     │
              │  Functions (AI layer)   │
              └───────────┬────────────┘
                          │  (server-side calls)
              ┌───────────▼────────────┐
              │   AI LAYER (0-cost)     │
              │  Local/free LLM +       │
              │  rule-based engine +    │
              │  free translation       │
              └─────────────────────────┘
```

**Key principle:** Apps never call AI providers directly. All AI runs through **Appwrite Functions** (server-side). This keeps API keys secret, centralises prompt logic, and lets you swap the AI backend without touching the apps.

**Three clients, one contract:** The three apps agree on the same collections and the same `status` enum. Customer writes a booking → Appwrite Realtime pushes it to Worker App and Admin Panel instantly. No polling.

---

## 3. Zero-Cost Technology Stack (FYP-optimised)

| Layer | Choice | Why (FYP + zero-cost) |
|---|---|---|
| Customer App | **Flutter** (Android) | Single codebase, matches your existing doc, free |
| Worker App | **Flutter** (Android) | Reuse shared packages/widgets |
| Admin Panel | **Flutter Web** or **React + Vite** | Web dashboard; Flutter Web keeps one language |
| Backend / BaaS | **Appwrite** (self-hosted via Docker, free) | Auth, DB, Realtime, Storage, Functions — all free, all-in-one |
| Real-time | **Appwrite Realtime** (WebSocket) | Built into Appwrite, no extra service |
| Maps | **flutter_map + OpenStreetMap tiles** | Free (Google Maps needs billing card); OSM is $0 |
| Routing/ETA | **OSRM public demo / GraphHopper free tier** | Free routing for navigation & ETA |
| AI / LLM | **Ollama (local) + rules engine** (see §4) | $0, offline-capable, no API bills |
| Translation | **AI LLM prompt** or **LibreTranslate (self-host)** | Free multilingual translation |
| Speech-to-text | **Vosk (offline) / device STT** | Free voice input |
| Push notifications | **Appwrite + Firebase Cloud Messaging (free tier)** | FCM free for reasonable volume |
| Hosting (demo) | **Localhost / free VPS / laptop** | Appwrite runs in Docker on your machine |

**Appwrite self-host quickstart:**
```bash
# Requires Docker Desktop
docker run -it --rm \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume "$(pwd)/appwrite:/usr/src/code/appwrite:rw" \
  --entrypoint="install" \
  appwrite/appwrite:latest
# Console then available at http://localhost/
```

> **Note:** If self-hosting is a hassle for the demo, Appwrite Cloud has a free tier that covers an FYP comfortably. Both are $0. Self-host gives you unlimited Functions execution which matters for the AI layer.

---

## 4. Zero-Cost AI Strategy (the key decision)

Aapki requirement: **AI features chahiye, cost = 0.** Real-world paid APIs (OpenAI, Claude, Google) FYP demo mein bill create karti hain. Solution: a **hybrid AI layer** = *local LLM* + *deterministic rules engine* + *free translation*. All runs inside Appwrite Functions.

### 4.1 The hybrid model

```
                 Appwrite Function: aiRouter
                          │
        ┌─────────────────┼──────────────────┐
        ▼                 ▼                  ▼
  RULES ENGINE       LOCAL LLM          FREE SERVICES
  (deterministic)    (Ollama)           (translate/STT)
  - price ranges     - category detect  - LibreTranslate
  - fraud flags      - chat replies     - Vosk speech
  - risk scoring     - summaries        
  - keyword scan     - offer messages   
```

**Why hybrid, not pure-LLM:**
- **Rules engine** handles anything that must be *fast, free, deterministic and explainable*: price bands, fraud keyword scans, location-mismatch math, risk scores. No model call needed → instant + reliable in a demo.
- **Local LLM (Ollama)** handles *natural language*: understanding Roman Urdu problems, generating professional messages, summaries, category classification when rules are ambiguous. Runs on your laptop/VPS, $0.

### 4.2 Recommended local models (all free via Ollama)

| Task | Model | Size | Notes |
|---|---|---|---|
| Chat / classification / summaries | `llama3.1:8b` or `qwen2.5:7b` | ~5 GB | Qwen is strong at Urdu/multilingual |
| Lightweight / low-RAM machines | `phi3:mini` or `gemma2:2b` | ~2 GB | Faster, weaker reasoning |
| Translation | Same LLM via prompt, or LibreTranslate | — | LLM handles Roman Urdu best |

```bash
# Install Ollama (Linux/Mac/Windows) — free
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5:7b          # multilingual, great for Urdu
ollama serve                    # exposes http://localhost:11434
```

### 4.3 Fallback ladder (so the demo never dies)

Every AI call follows this ladder — if one tier fails, drop to the next:

```
1. Local LLM (Ollama)          → best quality, $0
2. Rules engine only           → deterministic, always works
3. Cached/canned response      → last-resort so UI never blanks
```

This means **even with no GPU and no internet**, the app still shows a category, a price range, and a sensible message — critical for a live FYP presentation.

### 4.4 Optional: free-tier cloud LLM (if you want higher quality on demo day)

If your laptop can't run a local model well, these have generous free tiers (no card in some cases): **Groq** (free API, very fast Llama hosting), **Google AI Studio / Gemini** free tier, **OpenRouter** free models. Wire them behind the *same* `aiRouter` function as tier-1, keep Ollama/rules as fallback. Design stays identical.

---

## 5. Appwrite Backend — Complete Schema

One Appwrite **Database** (`handygo`) with the collections below. Attribute types use Appwrite conventions. `$id`, `$createdAt`, `$updatedAt` are automatic.

### 5.1 `users` (base profile for all roles)
| Attribute | Type | Notes |
|---|---|---|
| authId | string | Appwrite Auth user id |
| role | enum | `customer` \| `worker` \| `admin` |
| name | string | |
| phone | string | |
| email | string | |
| photoUrl | string | Storage file id |
| language | enum | `ur` \| `en` \| `roman_ur` |
| fcmToken | string | push token |
| status | enum | `active` \| `suspended` \| `blocked` |
| riskScore | integer | 0–100, AI-maintained |
| createdVia | string | signup source |

### 5.2 `customer_profiles`
| Attribute | Type | Notes |
|---|---|---|
| userId | string | → users.$id |
| defaultAddress | string | |
| currentLat | double | |
| currentLng | double | |
| emergencyContactName | string | |
| emergencyContactPhone | string | |
| savedAddresses | string[] | JSON: home/office/other |
| totalBookings | integer | |
| trustScore | integer | 0–100 |

### 5.3 `worker_profiles`
| Attribute | Type | Notes |
|---|---|---|
| userId | string | → users.$id |
| skills | string[] | e.g. `["plumbing","ac_repair"]` |
| experienceYears | integer | |
| serviceAreaLat | double | center |
| serviceAreaLng | double | |
| serviceRadiusKm | double | |
| cnicFrontUrl | string | Storage |
| cnicBackUrl | string | Storage |
| selfieUrl | string | Storage |
| verificationStatus | enum | `incomplete`\|`under_review`\|`approved`\|`rejected`\|`suspended` |
| availability | enum | `offline`\|`online`\|`busy`\|`break` |
| rating | double | avg |
| jobsCompleted | integer | |
| walletBalance | double | |
| pendingBalance | double | |
| performanceScore | integer | 0–100, AI-maintained |
| currentLat | double | live |
| currentLng | double | live |

### 5.4 `service_categories`
| Attribute | Type | Notes |
|---|---|---|
| name | string | Plumbing, Electrical, … |
| icon | string | |
| basePriceMin | double | for rules-engine estimate |
| basePriceMax | double | |
| avgDurationMins | integer | |
| keywords | string[] | for AI/rule category detection |

### 5.5 `bookings` (central collection)
| Attribute | Type | Notes |
|---|---|---|
| customerId | string | → users.$id |
| workerId | string | nullable until selected |
| categoryId | string | → service_categories |
| detectedByAI | boolean | category came from AI? |
| problemText | string | customer description |
| problemImages | string[] | Storage ids |
| voiceNoteUrl | string | Storage id, nullable |
| addressText | string | |
| lat | double | |
| lng | double | |
| scheduledAt | datetime | nullable = instant |
| aiEstimateMin | double | |
| aiEstimateMax | double | |
| aiDurationMins | integer | |
| aiUrgency | enum | `low`\|`normal`\|`high`\|`emergency` |
| aiConfidence | double | 0–1 |
| aiSuggestedSolution | string | |
| finalQuote | double | accepted worker quote |
| additionalCharges | double | approved extras |
| status | enum | see §7 |
| otp | string | 4-digit, service-start |
| ratingGiven | integer | 1–5, nullable |
| reviewText | string | nullable |

### 5.6 `worker_offers` (InDrive-style)
| Attribute | Type | Notes |
|---|---|---|
| bookingId | string | → bookings |
| workerId | string | → users |
| quote | double | |
| etaMins | integer | |
| distanceKm | double | |
| message | string | AI-generated offer text |
| reason | string | if custom quote |
| status | enum | `sent`\|`viewed`\|`accepted`\|`rejected`\|`expired` |
| isBestMatch | boolean | AI flag |
| flaggedSuspicious | boolean | AI price-guard flag |

### 5.7 `booking_status_history` (audit trail)
| Attribute | Type | Notes |
|---|---|---|
| bookingId | string | |
| status | string | new status |
| changedByRole | enum | `customer`\|`worker`\|`admin`\|`system` |
| changedById | string | |
| note | string | e.g. "Worker arrived at 7:42 PM" |
| timestamp | datetime | |

### 5.8 `messages` (chat)
| Attribute | Type | Notes |
|---|---|---|
| bookingId | string | |
| senderId | string | |
| senderRole | enum | customer\|worker |
| text | string | original |
| translatedText | string | AI auto-translation |
| detectedLang | string | |
| aiFlagged | boolean | threat/abuse/external-payment |
| flagReason | string | nullable |
| readAt | datetime | nullable |

### 5.9 `notifications`
| Attribute | Type | Notes |
|---|---|---|
| userId | string | recipient |
| role | enum | customer\|worker\|admin |
| type | string | offer/status/payment/sos/… |
| title | string | |
| body | string | |
| bookingId | string | nullable |
| read | boolean | |

### 5.10 `transactions`
| Attribute | Type | Notes |
|---|---|---|
| bookingId | string | |
| customerId | string | |
| workerId | string | |
| serviceCharges | double | |
| materialCharges | double | |
| platformFee | double | |
| discount | double | |
| total | double | |
| method | enum | `cod`\|`jazzcash`\|`easypaisa`\|`wallet` |
| status | enum | `pending`\|`paid`\|`failed`\|`refunded` |
| commission | double | |
| netToWorker | double | |

### 5.11 `worker_locations` (live tracking; high-write)
| Attribute | Type | Notes |
|---|---|---|
| workerId | string | |
| bookingId | string | active booking |
| lat | double | |
| lng | double | |
| heading | double | optional |
| timestamp | datetime | |

### 5.12 `sos_alerts`
| Attribute | Type | Notes |
|---|---|---|
| bookingId | string | nullable |
| raisedByRole | enum | customer\|worker |
| raisedById | string | |
| counterpartId | string | other party |
| emergencyType | string | see flow doc |
| lat | double | |
| lng | double | |
| recentMessages | string | JSON snapshot |
| evidenceUrls | string[] | voluntary media |
| deviceInfo | string | |
| aiRiskLevel | enum | `low`\|`medium`\|`high`\|`critical` |
| aiSummary | string | AI incident summary |
| aiSuggestedActions | string[] | |
| adminStatus | enum | `open`\|`acknowledged`\|`in_progress`\|`safe`\|`closed` |
| timeline | string | JSON of admin actions |

### 5.13 `fraud_reports`
| Attribute | Type | Notes |
|---|---|---|
| bookingId | string | nullable |
| reportedByRole | enum | customer\|worker |
| reportedById | string | |
| accusedId | string | |
| type | string | fake_booking/overcharge/… |
| description | string | |
| evidenceUrls | string[] | |
| aiSummary | string | |
| aiRecommendation | string | recommendation only |
| adminDecision | enum | `pending`\|`refund`\|`warning`\|`suspension`\|`ban`\|`dismissed` |
| status | enum | `open`\|`investigating`\|`resolved` |

### 5.14 `ai_logs` (auditability + debugging)
| Attribute | Type | Notes |
|---|---|---|
| feature | string | which AI feature |
| inputSnapshot | string | JSON |
| tierUsed | enum | `llm`\|`rules`\|`fallback` |
| output | string | JSON |
| latencyMs | integer | |
| relatedId | string | booking/sos/etc |

### 5.15 `analytics_daily` (admin dashboards)
| Attribute | Type | Notes |
|---|---|---|
| date | datetime | |
| totalBookings | integer | |
| completed | integer | |
| cancelled | integer | |
| revenue | double | |
| avgRating | double | |
| demandByCategory | string | JSON |
| workerShortageAreas | string | JSON |
| cancellationReasons | string | JSON |


---

## 6. Real-Time Sync Design

Appwrite Realtime pushes document events over WebSocket. Each app subscribes only to the channels relevant to its role — this is what makes "ek app mein action → doosri apps turant update" work.

### 6.1 Subscription map

| App | Subscribes to | Filters (client-side) |
|---|---|---|
| Customer | `bookings`, `worker_offers`, `messages`, `notifications`, `worker_locations`, `sos_alerts` | own `customerId` / active booking |
| Worker | `bookings` (searching state), `worker_offers`, `messages`, `notifications`, `transactions` | own skills+area / own `workerId` |
| Admin | ALL collections | none — sees everything live |

### 6.2 Flutter subscription example

```dart
final realtime = Realtime(client);

// Customer listens for offers on their booking
final sub = realtime.subscribe([
  'databases.handygo.collections.worker_offers.documents',
]);

sub.stream.listen((response) {
  final event = response.events.first; // create/update/delete
  final offer = response.payload;
  if (offer['bookingId'] == myBookingId) {
    if (event.contains('.create')) {
      addOfferToList(offer);      // "New offer received"
      showToast('New offer received');
    }
  }
});
```

### 6.3 The golden rule: write once, everyone reacts

There is **no direct app-to-app communication.** Every action is a document write to Appwrite; Realtime fans it out. Example — Worker taps "On the way":

```
Worker App → update bookings.$id { status: 'worker_on_the_way' }
           → create booking_status_history { ... }
Appwrite Realtime broadcasts:
   → Customer App updates tracking screen ("Worker is on the way")
   → Admin Panel updates live map marker → Travelling
```

Because the three apps share the same `status` enum, no translation of state is needed between them.

---

## 7. Booking State Machine (shared across 3 apps)

Same status names in all three apps (from your flow doc). Every transition writes a `booking_status_history` document.

```
draft
  → searching_workers      (customer submits, workers notified)
  → offers_received        (≥1 offer)
  → worker_selected        (customer accepts an offer)
  → confirmed              (worker acknowledges)
  → worker_on_the_way
  → worker_arrived
  → service_started        (OTP verified)
  → in_progress
  → completion_requested   (worker marks done)
  → payment_pending        (customer confirms completion)
  → completed              (payment settled)

Side states (from most states):
  → cancelled
  → disputed
  → refunded
```

### 7.1 Allowed transitions (guard table)

| From | Allowed next | Who triggers |
|---|---|---|
| draft | searching_workers | customer |
| searching_workers | offers_received, cancelled | system/customer |
| offers_received | worker_selected, cancelled | customer |
| worker_selected | confirmed, cancelled | worker/customer |
| confirmed | worker_on_the_way, cancelled | worker |
| worker_on_the_way | worker_arrived | worker |
| worker_arrived | service_started | worker (OTP) |
| service_started | in_progress | system |
| in_progress | completion_requested | worker |
| completion_requested | payment_pending | customer |
| payment_pending | completed | system/payment |
| any active | disputed, cancelled | customer/worker/admin |
| disputed | refunded, completed | admin |

Enforce this table in an Appwrite Function (`transitionBooking`) so no client can jump illegally (e.g. worker can't `service_started` without a valid OTP).


---

## 8. AI Feature Specifications

Every AI feature maps to: (a) which tier handles it (LLM / rules / both), (b) input, (c) output, (d) where it's stored. AI **only recommends**; humans decide.

### 8.1 Customer App AI features

| # | Feature | Tier | Input | Output → stored in |
|---|---|---|---|---|
| C1 | Multilingual chatbot (Urdu/English/Roman Urdu) | LLM | chat text + history | reply text → `messages` |
| C2 | Text/voice/image problem intake | LLM + STT + vision-lite | text / voice→text / image caption | normalised problem → `bookings.problemText` |
| C3 | Auto service-category detection | LLM primary, rules fallback (keyword match) | problem text | `bookings.categoryId`, `detectedByAI` |
| C4 | Estimate price, duration, urgency, solution | Rules (price band from category) + LLM (solution text) | category + problem + location | `aiEstimateMin/Max`, `aiDurationMins`, `aiUrgency`, `aiSuggestedSolution` |
| C5 | Recommend nearby verified workers | Rules (geo + skills + verified + rating) | booking lat/lng + category | ranked worker list |
| C6 | Compare offers (best price / fastest / top rating) | Rules (multi-criteria scoring) | all `worker_offers` for booking | `isBestMatch` flag |
| C7 | Suspicious price / external-payment / location-mismatch warning | Rules (thresholds + keyword) + LLM (chat scan) | offers, messages, worker GPS | `flaggedSuspicious`, warning banner |
| C8 | Auto-translate customer↔worker messages | LLM / LibreTranslate | message text | `messages.translatedText` |
| C9 | SOS + fraud report | Rules (risk scoring) + LLM (summary) | incident data | `sos_alerts`, `fraud_reports` |

### 8.2 Worker App AI features

| # | Feature | Tier | Input | Output |
|---|---|---|---|---|
| W1 | Show only skill+location-matched jobs | Rules (filter) | worker skills/area + open bookings | filtered job feed |
| W2 | Suggest a reasonable quote | Rules (price band) + LLM (adjust for complexity) | booking + market band | suggested quote number |
| W3 | Suggest required tools & materials | LLM | category + problem text | checklist |
| W4 | Generate professional offer message + reply drafts | LLM | booking + quote + tone | `worker_offers.message` / chat draft |
| W5 | Route, schedule & overlap management | Rules (time-window + OSRM ETA) | worker bookings + locations | conflict warnings, ordered route |
| W6 | Post-job professional work summary | LLM | job notes + before/after + materials | `bookings` summary field |
| W7 | Earnings, performance & profile-improvement tips | Rules (stats) + LLM (advice text) | worker history | dashboard insights |
| W8 | Detect fake booking / payment fraud / unsafe customer | Rules (patterns) + LLM (chat scan) | booking + chat + customer risk | worker warning |
| W9 | SOS + fraud report | same as C9 | | |

### 8.3 Admin Panel AI features

| # | Feature | Tier | Input | Output |
|---|---|---|---|---|
| A1 | Live bookings / online workers / SOS dashboard | Realtime (no AI) | live collections | dashboard |
| A2 | Detect fake accounts, fake bookings, payment fraud, high quotes, suspicious cancellations | Rules (anomaly patterns) + LLM (edge cases) | all activity | flagged list + reasons |
| A3 | Scan chats for threats, harassment, abuse, external-payment | LLM (classification) + rules (keyword) | `messages` | `aiFlagged` + reason |
| A4 | SOS risk level + summary | Rules (severity) + LLM (summary) | `sos_alerts` | `aiRiskLevel`, `aiSummary`, `aiSuggestedActions` |
| A5 | Complaint/chat/evidence AI summary | LLM | dispute bundle | `fraud_reports.aiSummary` |
| A6 | Customer & worker risk + performance score | Rules (weighted formula) | history | `riskScore`, `performanceScore` |
| A7 | Demand forecast, revenue analysis, worker-shortage, cancellation reasons | Rules (aggregation) + LLM (narrative) | `analytics_daily`, bookings | charts + insight text |
| A8 | AI recommends; admin decides | design constraint | all above | recommendation flag only |

**Governance rule wired into UI:** anywhere AI produces a decision-shaped output (ban, refund, suspension), the app shows it as a *recommendation card* with **Approve / Reject / Modify** buttons for the admin. AI never writes a final `adminDecision` directly.


---

## 9. AI Implementation — Prompts, Functions & Code

All AI lives in **Appwrite Functions** (Node.js runtime). Apps call functions via SDK; functions call Ollama / rules / translation and write results back to Appwrite.

### 9.1 Function inventory

| Function | Trigger | Purpose |
|---|---|---|
| `aiIntake` | HTTP (customer) | C2/C3/C4 — classify + estimate from text/voice/image |
| `aiChat` | HTTP (customer) | C1 — multilingual chatbot turn |
| `aiTranslate` | DB event on `messages.create` | C8 — auto-translate + scan (A3/C7) |
| `recommendWorkers` | HTTP (customer) | C5/C6 — geo/skill ranking + best-match |
| `priceGuard` | DB event on `worker_offers.create` | C7/A2 — flag suspicious quotes |
| `workerAssist` | HTTP (worker) | W2/W3/W4/W6/W7 — quotes, tools, messages, summary |
| `routePlanner` | HTTP (worker) | W5 — ETA + overlap detection |
| `sosProcessor` | DB event on `sos_alerts.create` | A4 — risk level + summary + actions |
| `fraudAnalyzer` | DB event on `fraud_reports.create` | A5 — evidence summary + recommendation |
| `scoreEngine` | Scheduled (cron) | A6 — recompute risk/performance scores |
| `analyticsRollup` | Scheduled (daily) | A7 — demand/revenue/shortage rollups |

### 9.2 The shared AI router (tiered fallback)

```javascript
// lib/aiRouter.js — called by every AI function
const OLLAMA = process.env.OLLAMA_URL || 'http://localhost:11434';

async function askLLM(system, user, { json = false } = {}) {
  try {
    const res = await fetch(`${OLLAMA}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: process.env.OLLAMA_MODEL || 'qwen2.5:7b',
        prompt: `${system}\n\nUser: ${user}\nAssistant:`,
        stream: false,
        format: json ? 'json' : undefined,
        options: { temperature: 0.3 },
      }),
      signal: AbortSignal.timeout(20000),
    });
    const data = await res.json();
    return { tier: 'llm', text: data.response };
  } catch (e) {
    return { tier: 'fallback', text: null, error: e.message };
  }
}

module.exports = { askLLM };
```

### 9.3 C3/C4 — category detection + estimate (`aiIntake`)

**Rules-first category match, LLM to disambiguate:**

```javascript
const { askLLM } = require('./lib/aiRouter');

module.exports = async ({ req, res, log }) => {
  const { problemText, lat, lng, imageCaption } = JSON.parse(req.body);
  const categories = await getCategories(); // from service_categories

  // Tier: rules — keyword scan
  let best = null, bestScore = 0;
  for (const c of categories) {
    const score = c.keywords.filter(k =>
      problemText.toLowerCase().includes(k)).length;
    if (score > bestScore) { bestScore = score; best = c; }
  }

  // Tier: LLM if rules unsure (ambiguous or Roman Urdu)
  let confidence = bestScore > 0 ? 0.6 + 0.1 * bestScore : 0;
  if (confidence < 0.7) {
    const sys = `You are HandyGo's service classifier. Categories: ${
      categories.map(c => c.name).join(', ')}.
Understand Urdu, English and Roman Urdu.
Return JSON: {"category":"...","confidence":0-1,"urgency":"low|normal|high|emergency","solution":"one-line advice in the user's language"}`;
    const out = await askLLM(sys, problemText + (imageCaption ? ` [image: ${imageCaption}]` : ''), { json: true });
    if (out.tier === 'llm') {
      const p = JSON.parse(out.text);
      best = categories.find(c => c.name === p.category) || best;
      confidence = p.confidence;
      var urgency = p.urgency, solution = p.solution;
    }
  }

  // Tier: rules — price/duration band from category (deterministic, $0)
  const estimate = {
    min: best.basePriceMin,
    max: best.basePriceMax,
    durationMins: best.avgDurationMins,
    urgency: urgency || 'normal',
    solution: solution || 'A verified worker will assess and fix the issue.',
    confidence,
  };

  return res.json({ categoryId: best.$id, ...estimate });
};
```

**Example output (matches your flow doc):**
```json
{ "categoryId":"carpentry","min":1500,"max":2300,
  "durationMins":90,"urgency":"normal","confidence":0.86,
  "solution":"Sofa leg repair — worker will bring wood glue and screws." }
```

### 9.4 C1 — multilingual chatbot (`aiChat`)

```javascript
const sys = `You are HandyGo's assistant. Reply in the SAME language the
user used (Urdu, English, or Roman Urdu). Be concise and professional.
If a home-service problem is described, confirm the category, ask ONE
follow-up if needed, and end with an estimated price range and a
"Book Service" suggestion. Never ask for payment outside the app.`;
const out = await askLLM(sys, userMessage);
```

### 9.5 C8/A3/C7 — translate + scan on message create (`aiTranslate`)

Triggered automatically when a `messages` document is created:

```javascript
module.exports = async ({ req, res }) => {
  const msg = JSON.parse(req.body).payload; // Appwrite event payload

  // Translate to the recipient's language (LLM)
  const tr = await askLLM(
    `Translate to ${recipientLang}. Return only the translation.`,
    msg.text);

  // Rules scan: external payment / abuse keywords
  const RED = ['jazzcash number','easypaisa','bank account','send money',
               'outside app','whatsapp par','account number'];
  const ABUSE = ['/* keyword list */'];
  const lower = msg.text.toLowerCase();
  const flagged = RED.some(k => lower.includes(k)) ||
                  ABUSE.some(k => lower.includes(k));

  await updateMessage(msg.$id, {
    translatedText: tr.text ?? msg.text,
    aiFlagged: flagged,
    flagReason: flagged ? 'possible external payment / abusive content' : null,
  });
  // if flagged → also create an admin notification + set warning banner
};
```

### 9.6 C5/C6 — worker recommendation + best match (`recommendWorkers`)

Pure rules — fast, free, explainable:

```javascript
function haversineKm(a, b) { /* standard formula */ }

async function recommend(booking) {
  const workers = await getVerifiedOnlineWorkers(booking.categoryId);
  const scored = workers
    .filter(w => w.skills.includes(booking.category))
    .map(w => {
      const dist = haversineKm(booking, w);
      return {
        w, dist,
        etaMins: Math.round(dist / 0.4),               // ~24km/h city
        score: w.rating * 20                           // rating weight
             - dist * 3                                // nearer = better
             + Math.min(w.jobsCompleted, 50) * 0.4,    // experience
      };
    })
    .filter(x => x.dist <= (booking.radius || 8))
    .sort((a, b) => b.score - a.score);

  // Best-match = top blended score, NOT lowest price (per your rule)
  if (scored[0]) scored[0].isBestMatch = true;
  return scored;
}
```

For offer comparison (C6), compute three labels on the offer set: **Best Price** (min quote), **Fastest** (min ETA), **Top Rated** (max rating), and **Best Match** (blended). Show all four tags so the customer chooses — never force lowest price.

### 9.7 C7/A2 — price guard (`priceGuard`)

```javascript
// Fires when a worker_offers doc is created
const band = category.basePriceMax;
if (offer.quote > band * 1.8) {
  flag(offer, 'Quote far above typical range');       // high-quote alert
}
// location mismatch: worker GPS vs claimed service area
if (haversineKm(workerGps, worker.serviceArea) > worker.serviceRadiusKm * 2) {
  warn(booking.customerId, 'Worker location looks inconsistent');
}
```

### 9.8 W2/W3/W4/W6 — worker assist (`workerAssist`)

```javascript
// W3 tools + W2 quote + W4 message in one LLM call, JSON out
const sys = `You are HandyGo's worker copilot. Given a job, return JSON:
{"suggestedQuote":number,"tools":[...],"materials":[...],
 "offerMessage":"professional message in customer's language"}
Keep the quote within a fair range of ${band.min}-${band.max} PKR.`;
const out = await askLLM(sys, JSON.stringify(job), { json: true });
```

For **W6 work summary** (post-job), feed job notes + material list + before/after presence → LLM returns a professional paragraph stored on the booking.

### 9.9 A4 — SOS processor (`sosProcessor`)

```javascript
// Fires on sos_alerts.create — must be FAST and reliable
// Tier 1: rules assign a base risk level (never depends on LLM)
const CRITICAL = ['threat','violence','robbery','medical'];
let risk = CRITICAL.includes(alert.emergencyType) ? 'critical' : 'high';

// Tier 2: LLM writes a short summary + suggested actions (best-effort)
const out = await askLLM(
  `Summarise this safety incident in 2 lines and list 3 admin actions. JSON: {"summary":"","actions":[]}`,
  JSON.stringify({ type: alert.emergencyType, chat: alert.recentMessages }),
  { json: true });

await updateSos(alert.$id, {
  aiRiskLevel: risk,
  aiSummary: out.tier === 'llm' ? JSON.parse(out.text).summary
                                : `${alert.emergencyType} reported — immediate review needed.`,
  aiSuggestedActions: out.tier === 'llm' ? JSON.parse(out.text).actions
                                : ['Open live location','Contact both parties','Pause booking'],
});
// Always create a red admin notification regardless of LLM success
```

> **Design note:** SOS risk level comes from **rules**, never solely from the LLM. If the model is down, a threat is still `critical`. The LLM only enriches the summary.

### 9.10 A6 — score engine (`scoreEngine`, scheduled)

Deterministic weighted formulas (transparent, defensible in FYP viva):

```
customer.riskScore   = 100 - (cancellations*8 + fraudReportsAgainst*20
                              + sosMisuse*15) , clamped 0..100 (low=good)
worker.performanceScore = rating*15 + completionRate*40
                              + onTimeRate*25 - complaints*10 , clamped 0..100
```


---

## 10. Safety System (SOS + Fraud) Implementation

Directly from your flow doc. **SOS is on both Customer and Worker apps.**

### 10.1 SOS trigger flow (both apps)

```
User presses & holds SOS (3s) / swipes to activate
 → pick emergency type
 → app attaches: GPS, bookingId, counterpart id, recent chat snapshot,
   device info, (optional voluntary media)
 → create sos_alerts document
 → sosProcessor function fires (risk + summary)
 → Realtime pushes red alert to Admin Panel
 → push notification to emergency contact
```

**Anti-accidental:** press-and-hold 3s OR swipe-to-activate (per flow doc).
**False-SOS protection:** no auto cancellation charge until admin reviews; escalation ladder warning → restriction → suspension → ban.

### 10.2 SOS placement (build checklist)

- **Customer:** active booking, tracking, in-progress, chat, Profile→Safety Center.
- **Worker:** accepted booking, navigation, customer-location, in-progress, chat, Profile→Safety Center.
- Floating red button during active service in both apps.

### 10.3 Admin SOS Control Center

Red banner + incident timeline + actions (Open Live Location, Call parties, Pause Booking, Block Payment, Cancel, Suspend, Mark Safe, Close). Every admin action appends to `sos_alerts.timeline`.

### 10.4 Fraud vs SOS separation

| | SOS | Fraud Report |
|---|---|---|
| Use | Immediate danger | Non-immediate financial/account issue |
| Response | Instant admin alert + live location | Normal investigation workflow |
| Collection | `sos_alerts` | `fraud_reports` |

Fraud workflow: report → evidence → account flagged → admin investigation → both-party response → decision (refund/warning/suspension/ban). AI writes `aiSummary` + `aiRecommendation` only; admin sets `adminDecision`.

---

## 11. Security, Roles & Permissions

- **Auth:** Appwrite Auth, email OTP (your flow), separate role stored in `users.role`.
- **Document-level permissions:** customers read/write only their bookings; workers read searching bookings in their area + their assigned bookings; admin has team-level read on all.
- **Server-only writes for sensitive fields:** `status` transitions, `otp`, `riskScore`, `adminDecision`, `commission` are written **only** by Appwrite Functions (API key), never by clients.
- **OTP gate:** `service_started` transition requires the 4-digit OTP to match `bookings.otp` — enforced in `transitionBooking` function.
- **Masked calls:** worker never sees the raw customer phone before acceptance (store only, expose via a call-proxy field/UI).
- **AI key isolation:** Ollama URL / any cloud key lives in Function env vars, never in the app bundle.
- **Rate-limit AI functions** to avoid a runaway loop draining a laptop's CPU during demo.

---

## 12. Screen-by-Screen Build Checklist

### Customer App
- [ ] Splash → language select → location permission → login/signup → email OTP → profile setup → home
- [ ] Home: location, search, AI Assistant button, categories, popular, previous bookings, recommended, active-booking card
- [ ] Service request: manual / AI chatbot / image — all writing to `bookings`
- [ ] AI estimate card (price, duration, urgency, confidence, solution, Book Service)
- [ ] Offers screen (InDrive-style compare: best price / fastest / top rated / best match)
- [ ] Live tracking (OSM map, worker marker, ETA, chat, call, cancel, SOS)
- [ ] OTP display for service start
- [ ] In-progress card + additional-charge approval
- [ ] Completion → invoice → payment → rating/review
- [ ] Safety Center + SOS + Report Fraud

### Worker App
- [ ] Registration (CNIC, selfie, skills, area, docs) → under-review state
- [ ] Dashboard (online toggle, earnings, requests, active job, rating, wallet, performance)
- [ ] Incoming request card (accept / custom offer / decline / ask) with AI quote + tools suggestion
- [ ] Navigation (OSM/OSRM route) + On-the-way / arrived
- [ ] OTP entry → service timer → material request → work notes
- [ ] Job completion + AI work summary + earnings breakdown
- [ ] Wallet + withdraw + AI performance tips
- [ ] Safety Center + SOS + Report Fraud

### Admin Panel
- [ ] Dashboard stat cards + live section + charts
- [ ] Worker verification queue (approve/reject/more-info/suspend/block + reason)
- [ ] Booking management (full detail + audit history + actions)
- [ ] Live operations map (marker statuses incl. SOS)
- [ ] Payments & finance audit
- [ ] Disputes & complaints (AI summary + decision buttons)
- [ ] SOS Control Center (red banner, timeline, actions)
- [ ] AI insights: fraud flags, chat-scan flags, risk/performance scores, demand forecast, revenue, shortage, cancellation reasons — each as recommendation cards

---

## 13. Development Phases & Timeline (≈12 weeks)

| Phase | Weeks | Deliverables |
|---|---|---|
| **0. Setup** | 1 | Appwrite (Docker) up, database + all collections + permissions created, Ollama installed & model pulled, shared Flutter package scaffolded, repo + env vars |
| **1. Auth & profiles** | 1–2 | Signup/login/OTP for all 3 roles, profile setup, worker verification flow, admin approves workers |
| **2. Core booking (no AI)** | 3–4 | Create booking → offers → select → status machine → tracking → OTP → completion → payment → rating. Real-time sync working across 3 apps |
| **3. Real-time hardening** | 4 | All Realtime subscriptions, notifications, live map, status history audit trail |
| **4. AI layer — intake** | 5–6 | `aiRouter`, `aiIntake`, `aiChat`, category detect, estimate, multilingual chatbot, image/voice intake |
| **5. AI layer — matching & assist** | 6–7 | `recommendWorkers`, best-match, `workerAssist` (quote/tools/message/summary), `priceGuard` |
| **6. AI layer — translate & safety scan** | 7–8 | `aiTranslate`, chat auto-translation, external-payment/abuse flags |
| **7. SOS & fraud** | 8–9 | SOS both apps, `sosProcessor`, admin SOS Control Center, `fraudAnalyzer`, fraud workflow |
| **8. Admin AI** | 9–10 | `scoreEngine`, `analyticsRollup`, fraud/anomaly flags, dashboards, recommendation cards |
| **9. Polish & real-feel** | 10–11 | Loading/empty/error states, notifications by role, UI consistency, button naming |
| **10. Demo mode + testing** | 11–12 | Seed demo accounts, end-to-end demo script, bug-fixing, viva prep |

**Team split (typical 2–3 person FYP):** one on Customer+Worker apps, one on Admin+backend/Functions, shared on AI layer.


---

## 14. Testing, Demo Mode & FYP Presentation

### 14.1 Demo accounts (seed)
```
Customer: Ammar        (customer@handygo.demo)
Worker:   Ali Electrician (worker@handygo.demo)
Admin:    HandyGo Admin (admin@handygo.demo)
```
Seed 3–4 extra workers around one area so offers actually appear.

### 14.2 End-to-end demo script (matches your flow doc)
```
Customer requests AC repair (via AI chatbot, Roman Urdu)
→ AI detects category + estimates Rs. 2,000–3,500
→ 3 workers send offers → customer compares (best price/fastest/top rated)
→ selects Ali → live tracking on map → OTP 4821 starts service
→ worker requests Rs. 500 material → customer approves
→ service completes → work summary auto-generated → online payment
→ 5-star rating → admin sees completed transaction + analytics update
```
Also demo one **SOS** and one **fraud flag** so the safety + AI-alert story is visible.

### 14.3 Testing matrix
- **Unit:** rules engine (price bands, scoring, geo), state-machine guards.
- **Integration:** each Appwrite Function with mock payloads; fallback ladder (kill Ollama → confirm rules still respond).
- **Real-time:** action in one app appears in the other two within ~1–2s.
- **AI quality spot-checks:** 10 Urdu, 10 English, 10 Roman-Urdu problem statements → correct category + sensible estimate.

### 14.4 Viva talking points
- Why hybrid AI (explainable rules + LLM for language) = reliable **and** free.
- Why AI only recommends, admin decides (safety/ethics).
- Real-time architecture: write-once, fan-out via Appwrite Realtime.
- Fallback ladder = demo never fails even offline.

---

## 15. Risk Register & Fallbacks

| Risk | Impact | Mitigation |
|---|---|---|
| Local LLM too slow on laptop | Laggy demo | Use smaller model (`phi3:mini`), or Groq free API tier as tier-1 |
| Ollama down mid-demo | AI features blank | Fallback ladder → rules + canned responses always answer |
| OSM/OSRM public demo rate-limited | Map/route fails | Cache tiles, self-host OSRM, or straight-line ETA fallback |
| Appwrite self-host setup pain | Lost time | Switch to Appwrite Cloud free tier (same code) |
| Real-time write storms (location) | DB pressure | Throttle `worker_locations` writes to every 5–10s |
| AI hallucinated category | Wrong booking | "Change Category" button always present (your flow doc) |
| Multilingual accuracy on Roman Urdu | Poor UX | Qwen2.5 handles it well; add keyword-rule backup |
| FYP scope creep | Missed deadline | Phases 0–3 (real-time booking) are the MVP floor; AI layers are additive |

---

## 16. Appendix

### 16.1 Function env vars
```
APPWRITE_ENDPOINT=http://localhost/v1
APPWRITE_PROJECT=handygo
APPWRITE_API_KEY=***           # server key, functions only
APPWRITE_DB=handygo
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=qwen2.5:7b
LIBRETRANSLATE_URL=http://localhost:5000   # optional
# Optional free-tier cloud fallback:
GROQ_API_KEY=***               # optional tier-1 upgrade
```

### 16.2 Suggested repo structure
```
handygo/
├── app_customer/        # Flutter
├── app_worker/          # Flutter
├── app_admin/           # Flutter Web or React
├── shared/              # shared Dart package: models, status enum, appwrite client
├── functions/
│   ├── lib/aiRouter.js
│   ├── aiIntake/
│   ├── aiChat/
│   ├── aiTranslate/
│   ├── recommendWorkers/
│   ├── priceGuard/
│   ├── workerAssist/
│   ├── routePlanner/
│   ├── sosProcessor/
│   ├── fraudAnalyzer/
│   ├── scoreEngine/
│   └── analyticsRollup/
├── seed/                # demo accounts + categories + sample workers
└── docs/                # this plan + flow docs
```

### 16.3 Seed: service_categories (starter data)
| Name | basePriceMin | basePriceMax | avgDurationMins | keywords |
|---|---|---|---|---|
| Plumbing | 800 | 2500 | 75 | leak, pipe, tap, nal, paani, drain |
| Electrical | 700 | 3000 | 60 | wiring, switch, bijli, current, breaker, socket |
| Carpentry | 1000 | 3500 | 90 | wood, sofa, door, darwaza, furniture, leg |
| Cleaning | 1500 | 5000 | 120 | clean, safai, dusting, wash |
| AC Repair | 1500 | 4000 | 90 | ac, cooling, gas, thanda, compressor |
| Appliance Repair | 1000 | 4000 | 80 | fridge, washing machine, microwave, kharab |
| Emergency Service | 1000 | 6000 | 60 | urgent, emergency, foran, jaldi |

### 16.4 Shared status enum (single source of truth)
```dart
enum BookingStatus {
  draft, searchingWorkers, offersReceived, workerSelected, confirmed,
  workerOnTheWay, workerArrived, serviceStarted, inProgress,
  completionRequested, paymentPending, completed,
  cancelled, disputed, refunded,
}
```

---

### Final note on scope
The **MVP floor** for a passing, impressive FYP is Phases 0–3: three real apps sharing one Appwrite backend with genuine real-time booking, offers, tracking, OTP, payment and rating — **zero dummy data**. Every AI layer on top (Phases 4–8) is additive and, thanks to the fallback ladder, degrades gracefully. Build the real-time skeleton first; layer AI second. That ordering guarantees you always have a working demo.

*End of development plan — Handy Go FYP.*
