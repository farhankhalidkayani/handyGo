// §9.8: W2/W3/W4/W6/W7. One LLM call returns quote/tools/materials/offer message for a new
// job (or, for mode "summary", a post-job work summary). Falls back to a deterministic
// mid-band quote and canned message if the LLM tier is unavailable.
const { getDatabases, DB_ID } = require('../lib/appwriteClient');
const { askLLM, safeJsonParse } = require('../lib/llm');

module.exports = async function workerAssist(body) {
  const { mode = 'quote', booking, jobNotes, materials, language = 'en' } = body;

  // Summary mode only needs jobNotes/materials, never a booking object — bug found live: this
  // check used to run unconditionally and rejected every summary-mode call with no booking.
  if (mode === 'summary') {
    const sys = `You are HandyGo's worker copilot. Write a short, professional post-job work
summary in language "${language}" from the job notes and materials used. 2-4 sentences.`;
    const out = await askLLM(sys, JSON.stringify({ jobNotes, materials }));
    const summary = out.tier === 'llm' && out.text
      ? out.text
      : `Job completed. Materials used: ${(materials || []).join(', ') || 'none'}.`;
    return { status: 200, body: { summary, tierUsed: out.tier === 'llm' ? 'llm' : 'fallback' } };
  }

  if (!booking) return { status: 400, body: { error: 'booking is required' } };

  const databases = getDatabases();
  const category = await databases.getDocument(DB_ID, 'service_categories', booking.categoryId).catch(() => null);
  const band = category ? { min: category.basePriceMin, max: category.basePriceMax } : { min: 500, max: 2000 };

  const sys = `You are HandyGo's worker copilot. Given a job, return JSON only:
{"suggestedQuote":number,"tools":[...],"materials":[...],
 "offerMessage":"professional message in language ${language}"}
Keep the quote within a fair range of ${band.min}-${band.max} PKR.`;
  const out = await askLLM(sys, JSON.stringify({ problemText: booking.problemText, category: category?.name }), {
    json: true,
  });

  let result;
  if (out.tier === 'llm') {
    result = safeJsonParse(out.text);
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

  return { status: 200, body: { ...result, tierUsed: out.tier === 'llm' ? 'llm' : 'fallback' } };
};
