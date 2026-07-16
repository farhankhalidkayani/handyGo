// §9.3: C2/C3/C4. Rules-first category match (keyword scan), LLM disambiguates when the
// rules engine is unsure (ambiguous text or Roman Urdu), then a deterministic price/duration
// band from the matched category. Never blocks on the LLM.
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');
const { askLLM, safeJsonParse } = require('../lib/llm');

const FALLBACK_SOLUTION = 'A verified worker will assess and fix the issue.';

module.exports = async function intake(body, { log }) {
  const start = Date.now();
  const { problemText = '', lat, lng, imageCaption } = body;
  if (!problemText.trim()) return { status: 400, body: { error: 'problemText is required' } };

  const databases = getDatabases();
  const categoriesRes = await databases.listDocuments(DB_ID, 'service_categories', [Query.limit(100)]);
  const categories = categoriesRes.documents;
  if (!categories.length) return { status: 500, body: { error: 'no service_categories seeded' } };

  let best = null;
  let bestScore = 0;
  const lower = problemText.toLowerCase();
  for (const c of categories) {
    const score = (c.keywords || []).filter((k) => lower.includes(k.toLowerCase())).length;
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }

  let confidence = bestScore > 0 ? Math.min(0.6 + 0.1 * bestScore, 0.95) : 0;
  let urgency = 'normal';
  let solution = FALLBACK_SOLUTION;
  let tierUsed = 'rules';

  if (confidence < 0.7) {
    const sys = `You are HandyGo's service classifier. Categories: ${categories
      .map((c) => c.name)
      .join(', ')}.
Understand Urdu, English and Roman Urdu.
Return JSON only: {"category":"...","confidence":0-1,"urgency":"low|normal|high|emergency","solution":"one-line advice in the user's language"}`;
    const userMsg = problemText + (imageCaption ? ` [image: ${imageCaption}]` : '');
    const out = await askLLM(sys, userMsg, { json: true });
    if (out.tier === 'llm') {
      const p = safeJsonParse(out.text);
      if (p) {
        best = categories.find((c) => c.name.toLowerCase() === String(p.category).toLowerCase()) || best;
        confidence = typeof p.confidence === 'number' ? p.confidence : confidence;
        urgency = p.urgency || urgency;
        solution = p.solution || solution;
        tierUsed = 'llm';
      }
    } else {
      log(`intake: LLM tier failed, using rules/fallback — ${out.error}`);
    }
  }

  if (!best) best = categories[0]; // last-resort so UI never blanks (§4.3)

  const result = {
    categoryId: best.$id,
    category: best.name,
    min: best.basePriceMin,
    max: best.basePriceMax,
    durationMins: best.avgDurationMins,
    urgency,
    solution,
    confidence,
  };

  await databases.createDocument(DB_ID, 'ai_logs', 'unique()', {
    feature: 'aiIntake',
    inputSnapshot: JSON.stringify({ problemText, lat, lng }),
    tierUsed,
    output: JSON.stringify(result),
    latencyMs: Date.now() - start,
    relatedId: '',
  }).catch(() => {});

  return { status: 200, body: result };
};
