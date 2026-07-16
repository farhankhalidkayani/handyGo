// aiChat — §9.4/C1: one multilingual chatbot turn. LLM-only feature; if the model is down we
// still return a canned reply so the chat UI never shows a blank bubble (§4.3 fallback ladder).
const { askLLM } = require('./lib/aiRouter');
const { getDatabases, DB_ID } = require('./lib/appwriteClient');

const SYSTEM_PROMPT = `You are HandyGo's assistant. Reply in the SAME language the
user used (Urdu, English, or Roman Urdu). Be concise and professional.
If a home-service problem is described, confirm the category, ask ONE
follow-up if needed, and end with an estimated price range and a
"Book Service" suggestion. Never ask for payment outside the app.`;

const CANNED_REPLY =
  "I'm having trouble reaching the assistant right now. You can still describe your problem and tap 'Book Service' — a category and price estimate will be shown, or you can pick a category manually.";

module.exports = async ({ req, res, error }) => {
  const start = Date.now();
  let body;
  try {
    body = JSON.parse(req.body || '{}');
  } catch {
    return res.json({ error: 'invalid JSON body' }, 400);
  }
  const { message = '', bookingId = '' } = body;
  if (!message.trim()) return res.json({ error: 'message is required' }, 400);

  const out = await askLLM(SYSTEM_PROMPT, message);
  const reply = out.tier === 'llm' && out.text ? out.text : CANNED_REPLY;

  const databases = getDatabases();
  await databases.createDocument(DB_ID, 'ai_logs', 'unique()', {
    feature: 'aiChat',
    inputSnapshot: JSON.stringify({ message }),
    tierUsed: out.tier === 'llm' ? 'llm' : 'fallback',
    output: JSON.stringify({ reply }),
    latencyMs: Date.now() - start,
    relatedId: bookingId,
  }).catch((e) => error(`ai_logs write failed: ${e.message}`));

  return res.json({ reply, tierUsed: out.tier === 'llm' ? 'llm' : 'fallback' });
};
