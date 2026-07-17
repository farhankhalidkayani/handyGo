// Admin-only: update an SOS alert's adminStatus + append a timeline entry (plan §10.3 SOS
// Control Center: Open Live Location, Call parties, Pause Booking, Block Payment, Cancel,
// Suspend, Mark Safe, Close). Authorization mirrors updateWorkerVerification.js — gated on the
// caller's real x-appwrite-user-id, not anything the client claims.
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

const ALLOWED = ['open', 'acknowledged', 'in_progress', 'safe', 'closed'];

module.exports = async function updateSosStatus(body, { req }) {
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

  const { sosAlertId, adminStatus, action, suspendUserId } = body;
  if (!sosAlertId || !ALLOWED.includes(adminStatus)) {
    return { status: 400, body: { error: `sosAlertId and adminStatus (one of ${ALLOWED.join(', ')}) are required` } };
  }

  const alert = await databases.getDocument(DB_ID, 'sos_alerts', sosAlertId).catch(() => null);
  if (!alert) return { status: 404, body: { error: 'sos alert not found' } };

  let timeline = [];
  try {
    timeline = JSON.parse(alert.timeline || '[]');
  } catch {
    timeline = [];
  }
  timeline.push({
    action: action || adminStatus,
    adminAuthId: callerAuthId,
    timestamp: new Date().toISOString(),
  });

  await databases.updateDocument(DB_ID, 'sos_alerts', sosAlertId, {
    adminStatus,
    timeline: JSON.stringify(timeline),
  });

  // Suspend (plan §10.3 SOS Control Center action set) — only ever the counterpart on this
  // specific alert, never an arbitrary user id, so an admin can't be tricked into suspending
  // someone unrelated to the incident.
  if (suspendUserId && [alert.raisedById, alert.counterpartId].includes(suspendUserId)) {
    await databases.updateDocument(DB_ID, 'users', suspendUserId, { status: 'suspended' }).catch(() => {});
  }

  return { status: 200, body: { ok: true, sosAlertId, adminStatus } };
};
