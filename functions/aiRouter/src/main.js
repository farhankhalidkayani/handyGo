// aiRouter — single HTTP Function fronting all app-invoked features (§9.1), consolidated
// from what the design plan lists as 6 separate functions (aiIntake/aiChat/recommendWorkers/
// workerAssist/routePlanner/transitionBooking) because Appwrite Cloud's free tier caps the
// number of Functions per project. Dispatches on body.feature; each handler is otherwise
// unchanged from its original single-purpose design.
const { parseBody } = require('./lib/parseBody');

const handlers = {
  intake: require('./handlers/intake'),
  chat: require('./handlers/chat'),
  recommendWorkers: require('./handlers/recommendWorkers'),
  workerAssist: require('./handlers/workerAssist'),
  routePlanner: require('./handlers/routePlanner'),
  transitionBooking: require('./handlers/transitionBooking'),
};

module.exports = async (ctx) => {
  const { req, res } = ctx;
  let body;
  try {
    body = parseBody(req);
  } catch {
    return res.json({ error: 'invalid JSON body' }, 400);
  }

  const handler = handlers[body.feature];
  if (!handler) {
    return res.json(
      { error: `unknown feature "${body.feature}". Valid: ${Object.keys(handlers).join(', ')}` },
      400
    );
  }

  const { status, body: responseBody } = await handler(body, ctx);
  return res.json(responseBody, status);
};
