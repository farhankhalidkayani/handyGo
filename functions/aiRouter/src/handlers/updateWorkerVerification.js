// Admin-only: approve/reject a worker's verification (plan §12 Admin Panel checklist).
// Authorization is NOT based on anything the client sends — Appwrite sets
// `x-appwrite-user-id` from the caller's actual session/JWT, so we look up that user's
// `role` server-side (API key bypasses permissions) rather than trusting a client-supplied
// admin flag. This is the lightweight stand-in for a proper Appwrite Teams-based ACL, which
// wasn't set up in Phase 0 — see the repo README's "known simplification" note.
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

const ALLOWED = ['approved', 'rejected', 'suspended'];

module.exports = async function updateWorkerVerification(body, { req }) {
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

  const { workerProfileId, status, reason, requestMoreInfo } = body;
  if (!workerProfileId) return { status: 400, body: { error: 'workerProfileId is required' } };

  // "Request more info" (plan §12 verification-queue checklist) deliberately doesn't change
  // verificationStatus — the worker stays in the under_review queue, this just asks a
  // question and waits, rather than forcing a premature approve/reject decision.
  if (requestMoreInfo) {
    if (!reason) return { status: 400, body: { error: 'reason is required when requesting more info' } };
    const worker = await databases.getDocument(DB_ID, 'worker_profiles', workerProfileId).catch(() => null);
    if (!worker) return { status: 404, body: { error: 'worker profile not found' } };
    await databases.createDocument(DB_ID, 'notifications', 'unique()', {
      userId: worker.userId,
      role: 'worker',
      type: 'verification_update',
      title: 'More information needed',
      body: reason,
      read: false,
    }).catch(() => {});
    return { status: 200, body: { ok: true, workerProfileId, requestMoreInfo: true } };
  }

  if (!ALLOWED.includes(status)) {
    return { status: 400, body: { error: `workerProfileId and status (one of ${ALLOWED.join(', ')}) are required` } };
  }
  if ((status === 'rejected' || status === 'suspended') && !reason) {
    return { status: 400, body: { error: 'reason is required when rejecting or suspending' } };
  }

  const worker = await databases.updateDocument(DB_ID, 'worker_profiles', workerProfileId, {
    verificationStatus: status,
  });

  await databases.createDocument(DB_ID, 'notifications', 'unique()', {
    userId: worker.userId,
    role: 'worker',
    type: 'verification_update',
    title: `Verification ${status}`,
    body: reason || `Your worker verification status is now "${status}".`,
    read: false,
  }).catch(() => {});

  return { status: 200, body: { ok: true, workerProfileId, status } };
};
