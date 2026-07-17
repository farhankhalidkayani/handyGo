// Admin-only: penalize a worker or customer (plan §12 Admin "Booking management" checklist)
// for something that doesn't rise to a full fraud investigation/dispute — e.g. a no-show or
// repeated lateness. Authorization mirrors updateWorkerVerification.js. This deliberately
// nudges performanceScore/riskScore rather than suspending/banning outright — those already
// have their own dedicated, more serious flows (updateWorkerVerification/updateFraudDecision).
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

module.exports = async function applyPenalty(body, { req }) {
  const callerAuthId = req.headers?.['x-appwrite-user-id'];
  if (!callerAuthId) return { status: 401, body: { error: 'no authenticated caller' } };

  const databases = getDatabases();
  const callerRes = await databases.listDocuments(DB_ID, 'users', [
    Query.equal('authId', callerAuthId),
    Query.limit(1),
  ]);
  const caller = callerRes.documents[0];
  if (!caller || caller.role !== 'admin') {
    return { status: 403, body: { error: 'admin role required' } };
  }

  const { bookingId, userId, reason, points = 10 } = body;
  if (!bookingId || !userId || !reason) {
    return { status: 400, body: { error: 'bookingId, userId, and reason are required' } };
  }
  const penaltyPoints = Math.min(Math.max(Number(points) || 10, 1), 100);

  const targetUser = await databases.getDocument(DB_ID, 'users', userId).catch(() => null);
  if (!targetUser) return { status: 404, body: { error: 'user not found' } };

  if (targetUser.role === 'worker') {
    const workerRes = await databases.listDocuments(DB_ID, 'worker_profiles', [
      Query.equal('userId', userId),
      Query.limit(1),
    ]);
    const worker = workerRes.documents[0];
    if (worker) {
      const newScore = Math.max(0, (worker.performanceScore || 50) - penaltyPoints);
      await databases.updateDocument(DB_ID, 'worker_profiles', worker.$id, { performanceScore: newScore });
    }
  } else {
    const newRisk = Math.max(0, (targetUser.riskScore || 100) - penaltyPoints);
    await databases.updateDocument(DB_ID, 'users', userId, { riskScore: newRisk });
  }

  await databases.createDocument(DB_ID, 'notifications', 'unique()', {
    userId,
    role: targetUser.role,
    type: 'penalty',
    title: 'A penalty was applied to your account',
    body: reason,
    bookingId,
    read: false,
  }).catch(() => {});

  return { status: 200, body: { ok: true, userId, penaltyPoints } };
};
