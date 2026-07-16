// §9.4/C1: one multilingual chatbot turn. LLM-only feature; if the model is down we still
// return a canned reply so the chat UI never shows a blank bubble (§4.3 fallback ladder).
const { getDatabases, DB_ID } = require('../lib/appwriteClient');
const { askLLM } = require('../lib/llm');

const SYSTEM_PROMPT = `You are HandyGo's assistant. Reply in the SAME language the
user used (Urdu, English, or Roman Urdu). Be concise and professional.
If a home-service problem is described, confirm the category, ask ONE
follow-up if needed, and end with an estimated price range and a
"Book Service" suggestion. Never ask for payment outside the app.`;

const CANNED_REPLY =
  "I'm having trouble reaching the assistant right now. You can still describe your problem and tap 'Book Service' — a category and price estimate will be shown, or you can pick a category manually.";

module.exports = async function chat(body) {
  const start = Date.now();
  const { message = '', bookingId = '' } = body;
  if (!message.trim()) return { status: 400, body: { error: 'message is required' } };

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
  }).catch(() => {});

  return { status: 200, body: { reply, tierUsed: out.tier === 'llm' ? 'llm' : 'fallback' } };
};
