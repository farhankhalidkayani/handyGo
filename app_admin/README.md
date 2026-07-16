# Admin Panel

Scaffolded as Flutter Web (`flutter create --platforms web`), per plan §3 option A — shares
`handygo_shared` (`BookingStatus` enum, collection ids) with the other two apps. Depends on
`appwrite` + the local `handygo_shared` path dependency. `dart analyze` is clean.

Run with `flutter run -d chrome`.

## What to build (plan §12, Admin Panel checklist)

- Dashboard stat cards + live section + charts; subscribes to **all** collections (§6.1)
- Worker verification queue (approve/reject/suspend/block)
- Booking management (full detail + audit history + actions)
- Live operations map (marker statuses incl. SOS)
- Payments & finance audit
- Disputes & complaints — `fraud_reports.aiSummary`/`aiRecommendation` shown as a recommendation
  card with Approve/Reject/Modify; admin action is the only thing that writes `adminDecision`
- SOS Control Center (red banner, timeline, actions) — reacts to `sos_alerts` realtime events
- AI insights: fraud flags, chat-scan flags, risk/performance scores, demand forecast (from
  `analytics_daily`, populated by the scheduled `analyticsRollup` Function)

Every AI-produced decision-shaped output must render as a recommendation card with
Approve/Reject/Modify — AI never writes a final `adminDecision` (plan §8.3 governance rule).
