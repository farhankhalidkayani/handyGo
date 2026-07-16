// §10.4/A5. Fires on fraud_reports.create. LLM summarises the evidence bundle and drafts a
// recommendation; admin always makes the final `adminDecision` (AI never writes it directly
// — governance rule in §8.3/A8).
const { getDatabases, DB_ID } = require('../lib/appwriteClient');
const { askLLM, safeJsonParse } = require('../lib/llm');

module.exports = async function fraud(report, { error }) {
  const sys = `You are HandyGo's dispute analyst. Summarise this fraud report in 2-3 sentences
and give ONE recommended next step (refund / warning / suspension / ban / dismiss) with a short
reason. Return JSON only: {"summary":"","recommendation":""}. This is a RECOMMENDATION ONLY —
the admin makes the final decision.`;
  const out = await askLLM(sys, JSON.stringify({
    type: report.type,
    description: report.description,
    evidenceUrls: report.evidenceUrls,
  }), { json: true });
  const parsed = out.tier === 'llm' ? safeJsonParse(out.text) : null;

  const databases = getDatabases();
  await databases.updateDocument(DB_ID, 'fraud_reports', report.$id, {
    aiSummary: parsed?.summary || `${report.type} report — manual review needed.`,
    aiRecommendation: parsed?.recommendation || 'dismiss (insufficient AI confidence, needs manual review)',
    status: 'investigating',
  });

  await databases.createDocument(DB_ID, 'notifications', 'unique()', {
    userId: 'admin',
    role: 'admin',
    type: 'fraud_report',
    title: `Fraud report: ${report.type}`,
    body: 'New fraud report ready for review.',
    bookingId: report.bookingId || null,
    read: false,
  }).catch((e) => error(`notification write failed: ${e.message}`));

  return { ok: true };
};
