// workerAssist — §9.8: W2/W3/W4/W6/W7. One LLM call returns quote/tools/materials/offer
// message for a new job (or, for mode "summary", a post-job work summary). Falls back to a
// deterministic mid-band quote and canned message if the LLM tier is unavailable.
const { getDatabases, DB_ID } = require('./lib/appwriteClient');
const { askLLM, safeJsonParse } = require('./lib/aiRouter');

module.exports = async ({ req, res, error }) => {
  let body;
  try {
    body = JSON.parse(req.body || '{}');
  } catch {
    return res.json({ error: 'invalid JSON body' }, 400);
  }
  const { mode = 'quote', booking, jobNotes, materials, language = 'en' } = body;
  if (!booking) return res.json({ error: 'booking is required' }, 400);

  const databases = getDatabases();
  const category = await databases.getDocument(DB_ID, 'service_categories', booking.categoryId).catch(() => null);
  const band = category ? { min: category.basePriceMin, max: category.basePriceMax } : { min: 500, max: 2000 };

  if (mode === 'summary') {
    const sys = `You are HandyGo's worker copilot. Write a short, professional post-job work
summary in language "${language}" from the job notes and materials used. 2-4 sentences.`;
    const out = await askLLM(sys, JSON.stringify({ jobNotes, materials }));
    const summary = out.tier === 'llm' && out.text
      ? out.text
      : `Job completed. Materials used: ${(materials || []).join(', ') || 'none'}.`;
    return res.json({ summary, tierUsed: out.tier === 'llm' ? 'llm' : 'fallback' });
  }

  // mode === 'quote': W2 quote + W3 tools/materials + W4 offer message, one JSON call
  const sys = `You are HandyGo's worker copilot. Given a job, return JSON only:
{"suggestedQuote":number,"tools":[...],"materials":[...],
 "offerMessage":"professional message in language ${language}"}
Keep the quote within a fair range of ${band.min}-${band.max} PKR.`;
  const out = await askLLM(sys, JSON.stringify({ problemText: booking.problemText, category: category?.name }), {
    json: true,
  });

  let result;
  if (out.tier === 'llm') {
    const parsed = safeJsonParse(out.text);
    result = parsed || null;
  }
  if (!result) {
    const mid = Math.round((band.min + band.max) / 2);
    result = {
      suggestedQuote: mid,
      tools: [],
      materials: [],
      offerMessage: `I can help with this job. My quote is Rs. ${mid}.`,
    };
  }

  return res.json({ ...result, tierUsed: out.tier === 'llm' ? 'llm' : 'fallback' });
};
