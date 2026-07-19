// eventRouter — single Function handling all DB-triggered events AND the daily scheduled
// jobs (§9.1), consolidated from what the plan lists as 6 separate functions
// (aiTranslate/priceGuard/sosProcessor/fraudAnalyzer/scoreEngine/analyticsRollup) because
// Appwrite Cloud's free tier caps a project at 2 Functions total. A single Function can carry
// both `events` and a `schedule` at once; `x-appwrite-trigger` tells us which kind of
// invocation this is.
const { parseBody } = require('./lib/parseBody');

const scoreEngine = require('./handlers/scoreEngine');
const analyticsRollup = require('./handlers/analyticsRollup');

// bookings has no own handler module — any create/update triggers both a full analytics
// recompute (admin Analytics tab, see analyticsRollup.js) and a full score recompute (worker
// performanceScore / customer riskScore, see scoreEngine.js — cheap at this dataset size,
// well within the function timeout), so both the Analytics tab and the AI Insights tab's
// worker-performance flags stay live instead of only updating at the daily scheduled run.
// Ignores the individual booking payload; both recompute from scratch.
const eventHandlers = {
  messages: require('./handlers/translate'),
  worker_offers: require('./handlers/priceGuard'),
  sos_alerts: require('./handlers/sos'),
  fraud_reports: require('./handlers/fraud'),
  bookings: async (doc, ctx) => {
    const [scores, analytics] = await Promise.all([scoreEngine(ctx), analyticsRollup(ctx)]);
    return { scores, analytics };
  },
};

function collectionFromEventHeader(headerValue) {
  const match = /\.collections\.([^.]+)\.documents\./.exec(headerValue || '');
  return match ? match[1] : null;
}

module.exports = async (ctx) => {
  const { req, res, log, error } = ctx;
  const trigger = req.headers?.['x-appwrite-trigger'];

  if (trigger === 'schedule') {
    const scores = await scoreEngine(ctx);
    log(`eventRouter/schedule: scoreEngine done — ${JSON.stringify(scores)}`);
    const analytics = await analyticsRollup(ctx);
    log(`eventRouter/schedule: analyticsRollup done — ${JSON.stringify(analytics)}`);
    return res.json({ ok: true, scores, analytics });
  }

  let doc;
  try {
    doc = parseBody(req);
  } catch {
    return res.json({ error: 'invalid event payload' }, 400);
  }
  doc = doc.payload || doc; // some payload shapes wrap the document as { payload: {...} }

  const eventHeader = req.headers?.['x-appwrite-event'];
  const collection = collectionFromEventHeader(eventHeader);
  const handler = collection && eventHandlers[collection];
  if (!handler) {
    error(`eventRouter: no handler for collection "${collection}" (event header: ${eventHeader})`);
    return res.json({ error: `no handler for collection "${collection}"` }, 400);
  }

  const result = await handler(doc, ctx);
  return res.json(result);
};
