// Admin-only: set a fraud report's final adminDecision (plan §10.4: "AI writes aiSummary +
// aiRecommendation only; admin sets adminDecision"). Authorization mirrors
// updateWorkerVerification.js/updateSosStatus.js — gated on the caller's real
// x-appwrite-user-id, not anything the client claims.
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

const ALLOWED_DECISIONS = ['refund', 'warning', 'suspension', 'ban', 'dismissed'];

module.exports = async function updateFraudDecision(body, { req }) {
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

  const { fraudReportId, adminDecision } = body;
  if (!fraudReportId || !ALLOWED_DECISIONS.includes(adminDecision)) {
    return {
      status: 400,
      body: { error: `fraudReportId and adminDecision (one of ${ALLOWED_DECISIONS.join(', ')}) are required` },
    };
  }

  const report = await databases.getDocument(DB_ID, 'fraud_reports', fraudReportId).catch(() => null);
  if (!report) return { status: 404, body: { error: 'fraud report not found' } };

  await databases.updateDocument(DB_ID, 'fraud_reports', fraudReportId, {
    adminDecision,
    status: 'resolved',
  });

  if (['suspension', 'ban'].includes(adminDecision) && report.accusedId) {
    await databases.updateDocument(DB_ID, 'users', report.accusedId, {
      status: adminDecision === 'ban' ? 'blocked' : 'suspended',
    }).catch(() => {});
  }

  return { status: 200, body: { ok: true, fraudReportId, adminDecision } };
};
