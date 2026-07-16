// §9.5: C8/A3/C7. Fires on messages.create. Translates for the recipient and runs a
// deterministic keyword scan for external-payment / abuse content — the scan never depends
// on the LLM tier so a flagged message is never missed just because Ollama is down.
const { getDatabases, DB_ID } = require('../lib/appwriteClient');
const { askLLM } = require('../lib/llm');

const RED_FLAGS = [
  'jazzcash number', 'easypaisa', 'bank account', 'send money',
  'outside app', 'whatsapp par', 'account number', 'iban',
];
const ABUSE = ['abuse', 'threat', 'kill', 'harass'];

module.exports = async function translate(msg, { error }) {
  const databases = getDatabases();
  const booking = await databases.getDocument(DB_ID, 'bookings', msg.bookingId).catch(() => null);
  const recipientRole = msg.senderRole === 'customer' ? 'worker' : 'customer';
  const recipientId = booking ? (recipientRole === 'customer' ? booking.customerId : booking.workerId) : null;
  const recipient = recipientId ? await databases.getDocument(DB_ID, 'users', recipientId).catch(() => null) : null;
  const recipientLang = recipient?.language || 'en';

  const tr = await askLLM(
    `Translate the user's message to language code "${recipientLang}". Return only the translation, no extra text.`,
    msg.text
  );

  const lower = (msg.text || '').toLowerCase();
  const flagged = RED_FLAGS.some((k) => lower.includes(k)) || ABUSE.some((k) => lower.includes(k));

  await databases.updateDocument(DB_ID, 'messages', msg.$id, {
    translatedText: tr.tier === 'llm' && tr.text ? tr.text : msg.text,
    detectedLang: msg.detectedLang || recipientLang,
    aiFlagged: flagged,
    flagReason: flagged ? 'possible external payment / abusive content' : null,
  });

  if (flagged && booking) {
    await databases.createDocument(DB_ID, 'notifications', 'unique()', {
      userId: 'admin',
      role: 'admin',
      type: 'chat_flag',
      title: 'Flagged message',
      body: `Message in booking ${msg.bookingId} flagged for review.`,
      bookingId: msg.bookingId,
      read: false,
    }).catch((e) => error(`notification write failed: ${e.message}`));
  }

  return { ok: true, flagged };
};
