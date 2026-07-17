# Handy Go — Test Cases (Phases 0–2 + AI intake/chat)

Living checklist of what to verify to confirm the app actually works. Organized by what's
built so far: backend/schema (Phase 0), auth/profiles (Phase 1), core booking flow (Phase 2),
AI-assisted intake/chat (early Phase 4 slice). Update this file as new phases land — add
sections, don't rewrite history.

**Legend:** ✅ = covered by an automated script in this repo (`seed/e2e_test.js` or similar) and
already verified passing · 🔲 = needs manual click-through (UI not exercised by any script).

---

## 0. Backend / infrastructure

| # | Test | Steps | Expected | Status |
|---|---|---|---|---|
| 0.1 | Schema provisioned | `node seed/provision.js` | All 15 collections exist with correct attributes/indexes; safe to re-run (idempotent) | ✅ |
| 0.2 | Demo data seeded | `node seed/seed.js` | 7 categories, 1 customer, 4 workers, 1 admin created; re-running doesn't duplicate categories (unique index) | ✅ |
| 0.3 | Functions deployed | `node functions/status.js` | `aiRouter` and `eventRouter` both show `status=ready` | ✅ |
| 0.4 | aiRouter reachable | `node seed/e2e_test.js` step 2 | Returns 200, not 401/404 | ✅ |
| 0.5 | eventRouter fires on DB events | Create a `fraud_reports` document directly | `aiSummary`/`aiRecommendation` populate within a few seconds, `status` → `investigating` | ✅ (manually verified earlier this session) |
| 0.6 | AI fallback ladder | Any aiRouter/eventRouter feature that calls `askLLM`, with `OLLAMA_URL` unreachable (current state — Cloud Functions can't reach localhost) | Feature still returns a valid response using the rules/canned fallback, `tierUsed: "fallback"`, never a 500 | ✅ |

---

## 1. Auth & profiles (Phase 1)

**Note:** seeded accounts use `@handygo.demo` — no real inbox. Use a **real email address**
for manual testing; a fresh Appwrite Auth user is created automatically on first OTP request.

| # | Test | App | Steps | Expected | Status |
|---|---|---|---|---|---|
| 1.1 | New customer signup | Customer | Splash → pick language → allow/skip location → enter real email → "Send code" → check inbox → enter code → "Verify" | Lands on Profile Setup (no `users` doc yet for this email) | 🔲 |
| 1.2 | Customer profile setup | Customer | Fill name + phone → Continue | Lands on Home with "Welcome, `<name>`"; a `users` + `customer_profiles` document now exists in Appwrite console | 🔲 |
| 1.3 | Returning customer | Customer | Fully close/reload the app after 1.2 | Splash skips straight to Home (session persisted, profile found) — no login screen shown | 🔲 |
| 1.4 | Logout | Customer/Worker/Admin | Tap logout icon | Returns to language-select (customer/worker) or login (admin); reopening app shows login again, not Home | 🔲 |
| 1.5 | New worker signup | Worker | Same OTP flow as 1.1, different email | Lands on Worker Registration (no `users` doc yet) | 🔲 |
| 1.6 | Worker registration | Worker | Fill name/phone/experience, select ≥1 skill, submit | Lands on "Under review" screen; `worker_profiles.verificationStatus == "under_review"` | 🔲 |
| 1.7 | Worker registration validation | Worker | Submit registration with 0 skills selected | Inline error "Select at least one skill", not submitted | 🔲 |
| 1.8 | Worker blocked until approved | Worker | Log out, log back in as the still-under-review worker from 1.6 | Still shows "Under review", not Dashboard | 🔲 |
| 1.9 | Admin approves worker | Admin | Log in with a `role: admin` account → Verifications tab → find the worker from 1.6 → Approve | Worker disappears from the queue | 🔲 |
| 1.10 | Worker unlocked after approval | Worker | Log out and back in as the worker approved in 1.9 | Now lands on Dashboard, not "Under review" | 🔲 |
| 1.11 | Admin reject path | Admin | Approve/reject a different test worker → Reject | Worker's `verificationStatus` → `rejected`; that worker's app shows the "not approved" message on next login | 🔲 |
| 1.12 | Non-admin blocked from Admin Panel | Admin | Log in to the Admin app with a customer or worker email | Shows "This account does not have admin access" screen, not the dashboard | 🔲 |
| 1.13 | Worker toggles availability | Worker | On Dashboard, flip the "Online" switch | Switch updates immediately; `worker_profiles.availability` flips between `online`/`offline` in Appwrite console | 🔲 (note: seeded demo workers currently lack this permission — see README; use a freshly-registered worker) |

---

## 2. Core booking flow (Phase 2)

Best tested with **two browser windows side by side**: one logged in as a customer, one as a
worker (use two different real emails, or one real + demo account role-swapped). Optionally a
third window as admin to watch bookings appear live.

| # | Test | App | Steps | Expected | Status |
|---|---|---|---|---|---|
| 2.1 | Create booking (manual path) | Customer | Home → "Pick a category manually" → pick category, enter problem + address → "Find workers" | Navigates to Offers screen; a new `bookings` document exists with `status: searching_workers`, `detectedByAI: false` | ✅ (scripted) / 🔲 (UI) |
| 2.2 | Booking validation | Customer | Try "Find workers" with empty description or address | Inline validation errors, not submitted | 🔲 |
| 2.3 | Worker sees the open job | Worker | Go online (1.13) with a skill matching the booking's category → Dashboard | The booking from 2.1 appears in "Open jobs matching your skills" | 🔲 |
| 2.4 | Worker sends offer | Worker | Tap "Offer" on the job → enter quote + ETA → Send | Returns to Dashboard; a `worker_offers` document exists with `status: sent` | 🔲 |
| 2.5 | Offer appears live (realtime) | Customer | Watch the Offers screen without refreshing while 2.4 happens in the other window | Offer appears within ~1-2s with no manual refresh — proves Realtime works | 🔲 |
| 2.6 | Multiple offers / tags | Worker ×2, Customer | Send 2+ offers with different quotes/ETAs from two worker accounts | Customer's Offers screen tags the cheapest "Best price" and fastest-ETA one "Fastest" | 🔲 |
| 2.7 | Accept an offer | Customer | Tap "Accept" on one offer | Navigates to Tracking screen; that offer → `accepted`, all other offers on this booking → `rejected`; `bookings.workerId`/`finalQuote`/`status` (`worker_selected`) update | ✅ (scripted) / 🔲 (UI) |
| 2.8 | Worker sees acceptance live | Worker | Watch Dashboard without refreshing while 2.7 happens | Active job card appears within ~1-2s | 🔲 |
| 2.9 | Worker confirms job | Worker | Open active job → "Confirm job" | Status → `confirmed`; customer's Tracking screen updates live to "Worker confirmed the job" | 🔲 |
| 2.10 | Worker en route / arrived | Worker | "I'm on the way" → "I've arrived" | Status progresses `worker_on_the_way` → `worker_arrived`; customer sees each update live | 🔲 |
| 2.11 | OTP gate — wrong code | Worker | At `worker_arrived`, enter a wrong 4-digit code → "Start service" | Rejected with an error, status stays `worker_arrived` | ✅ (scripted) / 🔲 (UI) |
| 2.12 | OTP gate — correct code | Worker | Read the OTP customer sees on their Tracking screen, enter it correctly | Status → `service_started` then auto → `in_progress` | ✅ (scripted) / 🔲 (UI) |
| 2.13 | Worker marks job done | Worker | On active job, "Mark job as done" | Status → `completion_requested`; customer's Tracking screen shows "Confirm & pay (COD)" button | 🔲 |
| 2.14 | Customer confirms & pays | Customer | Tap "Confirm & pay (COD)" | Status → `payment_pending` → `completed`; a `transactions` document is auto-created (`method: cod`, `status: paid`, commission ≈15% of total) | ✅ (scripted) / 🔲 (UI) |
| 2.15 | Rating flow | Customer | After 2.14, navigate to Rating screen (or reopen Home → tap the "Rate your last service" card) | Star picker + review box; Submit updates `bookings.ratingGiven`/`reviewText` and recomputes the worker's `worker_profiles.rating` average | ✅ (scripted) / 🔲 (UI) |
| 2.16 | Home reflects booking state | Customer | Return to Home after 2.15 | No more "active booking"/"rate" card shown — booking is fully closed out | 🔲 |
| 2.17 | Admin sees bookings live | Admin | Bookings tab, open before/during 2.1–2.14 | Booking appears and its status line updates live at each step, with no page refresh | 🔲 |

---

## 2b. AI-assisted intake & chat

**Update:** Groq (`llama-3.1-8b-instant`) is now configured as tier-1 on both Functions —
confirmed live via `ai_logs` (`tierUsed: "llm"`, ~300ms–1s latency) for both `aiIntake` and
`aiChat`. One quality note found during that verification: for an ambiguous Roman Urdu prompt,
the model returned the free-text "solution" field in Devanagari/Hindi script rather than Roman
Urdu — category detection and price band were still correct. Worth spot-checking across more
Urdu/Roman Urdu phrasings (2b.2) rather than assuming it's fixed.

| # | Test | App | Steps | Expected | Status |
|---|---|---|---|---|---|
| 2b.1 | AI intake — clear match | Customer | Home → "Request a service" (default AI path) → type a problem with an obvious keyword (e.g. "AC gas leak, not cooling") → "Get AI estimate" | Estimate card shows the right category (AC Repair) with a price range, duration, urgency, and confidence ≥ 0.7 (rules tier matched, no LLM needed) | 🔲 |
| 2b.2 | AI intake — ambiguous / Roman Urdu | Customer | Type a vague or Roman Urdu description with no obvious keyword match | Still returns *some* category + price band (never blank) — confidence may be lower since it fell to the LLM tier or the last-resort default | 🔲 |
| 2b.3 | AI intake — override category | Customer | After getting an estimate, change the category dropdown to something else → "Book service" | Booking is created with the manually-picked category; `bookings.detectedByAI` is `false` (since it was overridden) | 🔲 |
| 2b.4 | AI intake — accept AI suggestion | Customer | Get an estimate, leave the category as suggested → "Book service" | `bookings.detectedByAI: true`, and `aiEstimateMin/Max`, `aiDurationMins`, `aiUrgency`, `aiConfidence`, `aiSuggestedSolution` are all populated on the booking document | 🔲 |
| 2b.5 | AI intake validation | Customer | Tap "Get AI estimate" with an empty problem field | Inline error "Describe the problem first", no call made | 🔲 |
| 2b.6 | AI chat — basic turn | Customer | Home → AI Assistant icon (top right) → type a message → send | A reply appears below; with no LLM configured, expect the canned fallback message, not a blank/error bubble | 🔲 |
| 2b.7 | AI chat → booking shortcut | Customer | From the chat screen, tap "Book Service" in the app bar | Navigates to the AI intake screen (2b.1) | 🔲 |
| 2b.8 | ai_logs written | Backend | After 2b.1/2b.6, check the `ai_logs` collection in Appwrite console | New documents exist with `feature: "aiIntake"`/`"aiChat"`, `tierUsed`, and `latencyMs` populated | 🔲 |

---

## 2c. In-booking chat (customer ↔ worker) + auto-translate/flagging

Verified live with a scripted message (not through the UI yet): creating a `messages` document
correctly triggers `eventRouter`'s `translate` handler within ~5-10s (event executions are
async — don't check/clean up test data too quickly, a race condition here initially looked
like a broken handler when it was actually a test-script timing bug).

**Known quality issue found:** when the message is already in the recipient's language (e.g.
both parties set to English), the translate prompt sometimes gets answered conversationally by
the LLM instead of returned verbatim as "no-op translation" — worth a closer look at the prompt
in `functions/eventRouter/src/handlers/translate.js` if this shows up often in real usage.

| # | Test | App | Steps | Expected | Status |
|---|---|---|---|---|---|
| 2c.1 | Send a message | Customer/Worker | Tracking screen (customer) or Active Job screen (worker) → chat icon → type + send | Message appears immediately in the sender's own view | 🔲 |
| 2c.2 | Message appears live for the other party | Customer + Worker | Watch the other party's chat screen without refreshing while 2c.1 happens | Message appears within ~1-2s (realtime) | 🔲 |
| 2c.3 | Translation appears | Customer/Worker | Send a message in a language different from the recipient's `users.language` | Within ~5-10s, an italicized translated line appears under the original message for the recipient | 🔲 |
| 2c.4 | External-payment flag | Customer/Worker | Send a message mentioning "jazzcash number" / "send money" / "outside app" | Within ~5-10s, the message bubble turns red-tinted with a "⚠ possible external payment / abusive content" note; an admin notification is created (`eventRouter`'s translate handler, verified live via script) | ✅ (scripted) / 🔲 (UI) |
| 2c.5 | Flag is never client-controlled | — | Inspect `message_repository.dart`'s `sendMessage` | Creates with `permissions: []` — sender can never set `aiFlagged`/`translatedText` themselves, only `eventRouter` (server-side) can | ✅ (code review) |

---

## 2d. SOS safety alerts

Verified live end-to-end via script: create alert → risk assessment fires automatically →
admin resolves via a real admin session. **Found and fixed a real bug in the process:**
`aiSuggestedActions: parsed?.actions || CANNED_ACTIONS` never fell back to the canned list when
the LLM returned an empty array — `[] || x` evaluates to `[]` in JS (empty arrays are truthy).
Fixed to check `.length` explicitly. Also confirmed risk level is rules-based and unaffected by
the LLM tier either way (`threat`/`violence`/`robbery`/`medical` → always `critical`).

| # | Test | App | Steps | Expected | Status |
|---|---|---|---|---|---|
| 2d.1 | Hold-to-activate (too short) | Customer/Worker | On Tracking/Active Job screen, tap-and-release the red SOS button quickly | Nothing happens — the progress ring resets, no alert filed | 🔲 |
| 2d.2 | Hold-to-activate (full 3s) | Customer/Worker | Press and hold the SOS button for the full 3 seconds | Progress ring fills, then an emergency-type picker dialog appears | 🔲 |
| 2d.3 | File an alert | Customer/Worker | Pick an emergency type from the dialog | Snackbar "SOS sent. Admin has been alerted."; a `sos_alerts` document is created with `adminStatus: open` | ✅ (scripted) / 🔲 (UI) |
| 2d.4 | Risk level always set, rules-based | Backend | Check the alert from 2d.3 a few seconds later | `aiRiskLevel` is `critical` for threat/violence/robbery/medical, `high` otherwise — set immediately regardless of LLM tier | ✅ (scripted) |
| 2d.5 | Admin sees it live | Admin | SOS tab, open before/during 2d.3 | New alert card appears within ~1-2s, color-coded by risk level, with AI summary + suggested action chips once the processor finishes | 🔲 |
| 2d.6 | Admin resolves alert | Admin | Tap "Mark safe" or "Close" on an alert | Card disappears from the open-alerts list; `sos_alerts.adminStatus` updates and `timeline` gets a new entry with the admin's authId + timestamp | ✅ (scripted) / 🔲 (UI) |
| 2d.7 | Non-admin can't resolve alerts | — | Call `aiRouter` with `feature: updateSosStatus` using a customer/worker session | 403 `"admin role required"` (same pattern as 3.3, not yet scripted for this specific feature) | 🔲 |
| 2d.8 | Unauthenticated call rejected | Backend | Call `updateSosStatus` via the server API key directly (no real session) | 401 `"no authenticated caller"` | ✅ |
| 2d.9 | SOS never blocked by GPS | Customer/Worker | Deny location permission, then file an SOS | Alert still files successfully with `lat`/`lng` empty — never blocks on GPS | 🔲 |

---

## 3. Security / permission checks

These matter more than they look — Appwrite's default document permissions are easy to get
wrong, and two real gaps were already found and fixed this way (see git log). Re-run after any
schema or permission change.

| # | Test | How | Expected | Status |
|---|---|---|---|---|
| 3.1 | Customer can't write booking status directly | `seed/e2e_test.js` step 1b, or manually via Appwrite console REST call as a real user session | Request rejected ("not authorized") | ✅ |
| 3.2 | Worker can't edit their own offer post-creation | Attempt a client-side `updateDocument` on a `worker_offers` doc as the owning worker | Rejected — offer status changes only happen via `selectOffer`/`priceGuard` (server-side) | 🔲 (covered implicitly by 3.1's fix landing in `offer_repository.dart`; not yet scripted separately) |
| 3.3 | Non-admin can't approve/reject workers | Call `aiRouter` with `feature: updateWorkerVerification` using a customer/worker session | 403 `"admin role required"` | 🔲 |
| 3.4 | Unauthenticated call to admin feature | Call `updateWorkerVerification` via the server API key directly (no real user session) | 401 `"no authenticated caller"` | ✅ |
| 3.5 | OTP required for service_started | Covered by 2.11/2.12 | — | ✅ |
| 3.6 | Non-admin can't resolve SOS alerts | Call `aiRouter` with `feature: updateSosStatus` using a customer/worker session | 403 `"admin role required"` | 🔲 (deny path verified for updateFraudDecision — 3.7 — same code pattern, not yet scripted separately for this feature) |
| 3.7 | Non-admin can't set fraud adminDecision | `seed` script: call `updateFraudDecision` with no session, then with a real admin session | 401 without a session, 200 + correct `adminDecision`/`status: resolved` with a real admin session | ✅ |

---

## 2e. Fraud reporting

Verified live end-to-end via script: file report → `eventRouter`'s `fraud` handler fires
automatically → `aiSummary`/`aiRecommendation` populate within ~10s → admin decision (both the
401 deny-without-session and 200 allow-with-real-admin-session paths confirmed).

| # | Test | App | Steps | Expected | Status |
|---|---|---|---|---|---|
| 2e.1 | File a report | Customer/Worker | Tracking (customer) or Active Job (worker) screen → flag icon → pick type + description → Submit | Snackbar confirms submission; a `fraud_reports` document is created with `status: open`, `adminDecision: pending` | ✅ (scripted) / 🔲 (UI) |
| 2e.2 | AI summary + recommendation appear | Backend | Check the report from 2e.1 a few seconds later | `aiSummary` and `aiRecommendation` populate (one of refund/warning/suspension/ban/dismiss) — recommendation only, never auto-applied | ✅ (scripted) |
| 2e.3 | Report validation | Customer/Worker | Tap "Submit report" with an empty description | Inline error "Please describe what happened", not submitted | 🔲 |
| 2e.4 | Admin sees it live | Admin | Fraud tab, open before/during 2e.1 | New report card appears within ~1-2s with the AI summary/recommendation shown once the analyzer finishes | 🔲 |
| 2e.5 | Admin makes a decision | Admin | Tap any decision button (dismissed/warning/refund/suspension/ban) | Card disappears from the open-reports list; `fraud_reports.adminDecision`/`status: resolved` update | ✅ (scripted) / 🔲 (UI) |
| 2e.6 | Suspension/ban updates the accused's account | Backend | Pick "suspension" or "ban" in 2e.5 for a report with a real `accusedId` | The accused user's `users.status` updates to `suspended`/`blocked` | 🔲 (logic implemented in `updateFraudDecision.js`, not yet scripted) |

---

## 2f. workerAssist (quote suggestion + work summary)

**Found and fixed a real bug live:** `workerAssist`'s `mode: "summary"` call unconditionally
required a `booking` object even though summary mode only uses `jobNotes`/`materials` — every
summary-mode call was rejected with 400 until fixed. Verified both modes work after the fix.

**Quality note:** the work summary sometimes includes a meta preamble ("Here's a short,
professional post-job work summary:") before the actual summary text instead of just the
summary — not blocking, worth a prompt tweak if it shows up often.

| # | Test | App | Steps | Expected | Status |
|---|---|---|---|---|---|
| 2f.1 | Quote suggestion pre-fills | Worker | From the open-jobs list, tap "Offer" on a job | Quote/message fields pre-fill with an AI suggestion within a couple seconds; suggested tools/materials shown above the form | ✅ (scripted) / 🔲 (UI) |
| 2f.2 | Quote suggestion is editable, not required | Worker | Edit the pre-filled quote before sending, or send if the AI call is slow/fails | Offer sends with whatever is actually in the fields — AI suggestion never blocks sending | 🔲 |
| 2f.3 | Work summary generated on completion | Worker | On "Mark job as done", fill in job notes + materials (comma-separated) → Done | `bookings.workSummary` populates with an AI-written summary; booking still transitions to `completion_requested` even if the AI call fails | ✅ (scripted, feature-level) / 🔲 (UI) |
| 2f.4 | workSummary is server-only | — | Inspect `transitionBooking.js` | `workSummary` is only ever set when transitioning to `completion_requested` through this function — no direct client update path exists on `bookings` | ✅ (code review) |

---

## 2g. Additional-charge approval + booking cancellation

Verified live end-to-end via script: request → `bookings.pendingAdditionalCharge`/`-Reason`
populate → approve → amount moves into `additionalCharges` and pending fields clear. The
amount is stored server-side and read back at approval time rather than trusted from the
client, so a customer can't quietly approve a different amount than what was actually
requested (see `requestAdditionalCharge.js`/`approveAdditionalCharge.js`).

| # | Test | App | Steps | Expected | Status |
|---|---|---|---|---|---|
| 2g.1 | Worker requests a charge | Worker | Active Job screen, while `in_progress` → "Request additional charge" → amount + reason → Request | Button replaced with "Waiting for customer to approve..." text; customer gets a notification | ✅ (scripted) / 🔲 (UI) |
| 2g.2 | Customer sees the request live | Customer | Tracking screen, open before/during 2g.1 | An approval card appears within ~1-2s showing the amount + reason, with Approve/Decline buttons | 🔲 |
| 2g.3 | Approve | Customer | Tap "Approve" on the card | `bookings.additionalCharges` increases by the requested amount, `pendingAdditionalCharge` clears, card disappears; worker gets a notification | ✅ (scripted) / 🔲 (UI) |
| 2g.4 | Decline | Customer | Tap "Decline" instead | `pendingAdditionalCharge` clears without changing `additionalCharges`; worker gets a notification | 🔲 (approve path scripted; decline path not yet scripted separately, same code path) |
| 2g.5 | Cancel before service starts | Customer/Worker | Tracking/Active Job screen, at any status before `service_started` → "Cancel booking" → confirm | Booking transitions to `cancelled`; screen closes | ✅ (scripted) / 🔲 (UI) |
| 2g.6 | No cancel option mid-service | Customer/Worker | Check the screen once status is `service_started`/`in_progress`/`completion_requested` | "Cancel booking" button is not shown | 🔲 |

---

## 2h. Photo attachment + more SOS Control Center actions

Verified live: a real customer session (not the API key) can upload directly to the
`problem_media` bucket, and the admin-gated suspend action correctly updates a real user's
`users.status` (tested against a live seeded account, then restored back to `active`
afterward).

| # | Test | App | Steps | Expected | Status |
|---|---|---|---|---|---|
| 2h.1 | Attach a photo | Customer | AI intake screen, after getting an estimate → "Attach a photo" → pick an image | Button label updates to show photo count; upload happens in the background | 🔲 |
| 2h.2 | Photo persists on the booking | Customer | Complete booking creation after 2h.1 | `bookings.problemImages` contains the uploaded file id(s) | ✅ (upload path scripted; full booking-attach flow not yet scripted) |
| 2h.3 | Photo upload never blocks booking | Customer | Attempt to book without attaching a photo | Booking still creates normally — photo attachment is optional | 🔲 |
| 2h.4 | Admin calls the SOS raiser | Admin | SOS tab → any alert → "Call raiser" | Opens the device's phone dialer with the raiser's number (if one is on file); shows an error if no phone number exists | 🔲 |
| 2h.5 | Admin suspends the counterpart | Admin | SOS tab → any alert with a `counterpartId` → "Suspend counterpart" → confirm | Confirmation dialog, then the counterpart's `users.status` → `suspended` immediately; a timeline entry is added to the alert | ✅ (scripted) / 🔲 (UI) |
| 2h.6 | Suspend only ever targets this alert's parties | — | Inspect `updateSosStatus.js` | `suspendUserId` is only honored if it equals the alert's own `raisedById` or `counterpartId` — an admin (or a compromised client) can't be tricked into suspending an unrelated user id | ✅ (code review) |

---

## 4. Known gaps (not yet built — don't file these as bugs)

Live map/ETA rendering, dispute resolution flow (distinct from a plain cancel, which is built —
§2g), voice problem intake / auto image-captioning into the AI classifier (photo attachment
itself is built — §2h), and the rest of the SOS Control Center action set (Open Live Location,
Pause Booking, Block Payment, Cancel — Acknowledge/In progress/Mark safe/Close/Call/Suspend are
built, §2d/§2h) — these are Phase 3+ per the plan's phase ordering (§13). Additional-charge
approval and booking cancellation are now
built (§2g). Fraud reporting is now built (§2e). Cloud LLM (Groq) is now configured and
confirmed live (§2b) — §0.6's fallback-ladder behavior still applies if Groq
itself is ever unreachable/rate-limited, just isn't the current normal path anymore.
