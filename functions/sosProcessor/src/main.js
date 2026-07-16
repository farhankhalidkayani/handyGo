// sosProcessor — §9.9: A4. Fires on sos_alerts.create. Risk level is ALWAYS rules-based —
// never depends on the LLM — so a threat is still `critical` even if the model is down
// (explicit design note in the plan, §9.9). The LLM only enriches the summary/actions,
// best-effort. The admin notification is created unconditionally.
const { getDatabases, DB_ID } = require('./lib/appwriteClient');
const { askLLM, safeJsonParse } = require('./lib/aiRouter');

const CRITICAL_TYPES = ['threat', 'violence', 'robbery', 'medical'];
const CANNED_ACTIONS = ['Open live location', 'Contact both parties', 'Pause booking'];

module.exports = async ({ req, res, error }) => {
  let event;
  try {
    event = JSON.parse(req.body || '{}');
  } catch {
    return res.json({ error: 'invalid event payload' }, 400);
  }
  const alert = event.payload || event;
  if (!alert || !alert.$id) return res.json({ error: 'no alert payload' }, 400);

  const risk = CRITICAL_TYPES.includes(alert.emergencyType) ? 'critical' : 'high';

  const out = await askLLM(
    'Summarise this safety incident in 2 lines and list 3 admin actions. Return JSON only: {"summary":"","actions":[]}',
    JSON.stringify({ type: alert.emergencyType, chat: alert.recentMessages }),
    { json: true }
  );
  const parsed = out.tier === 'llm' ? safeJsonParse(out.text) : null;

  const databases = getDatabases();
  await databases.updateDocument(DB_ID, 'sos_alerts', alert.$id, {
    aiRiskLevel: risk,
    aiSummary: parsed?.summary || `${alert.emergencyType} reported — immediate review needed.`,
    aiSuggestedActions: parsed?.actions || CANNED_ACTIONS,
  });

  // Always create a red admin notification regardless of LLM success (§9.9)
  await databases.createDocument(DB_ID, 'notifications', 'unique()', {
    userId: 'admin',
    role: 'admin',
    type: 'sos',
    title: `SOS: ${alert.emergencyType} (${risk})`,
    body: `Raised by ${alert.raisedByRole} ${alert.raisedById}`,
    bookingId: alert.bookingId || null,
    read: false,
  }).catch((e) => error(`admin notification write failed: ${e.message}`));

  return res.json({ ok: true, riskLevel: risk });
};
