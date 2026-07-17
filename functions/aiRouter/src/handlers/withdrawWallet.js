// Worker-only: withdraw the full wallet balance (plan §12 Worker checklist "Wallet + withdraw").
// walletBalance is server-only (only ever credited by transitionBooking.js on completion), so
// this is the only place it's ever debited. A real payout rail (bank transfer/JazzCash/etc.) is
// out of scope for the FYP — same "instant COD settlement" simplification already used for
// payment itself — this just zeroes the balance as if the payout succeeded, but logs it to
// wallet_withdrawals so the Admin Finance tab has a real audit trail (plan §12 "Payments &
// finance audit").
const { Query, Permission, Role } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

module.exports = async function withdrawWallet(body, { req }) {
  const callerAuthId = req.headers?.['x-appwrite-user-id'];
  if (!callerAuthId) return { status: 401, body: { error: 'no authenticated caller' } };

  const { workerProfileId } = body;
  if (!workerProfileId) return { status: 400, body: { error: 'workerProfileId is required' } };

  const databases = getDatabases();
  const callerRes = await databases.listDocuments(DB_ID, 'users', [
    Query.equal('authId', callerAuthId),
    Query.limit(1),
  ]);
  const caller = callerRes.documents[0];
  if (!caller) return { status: 401, body: { error: 'caller has no user document' } };

  const worker = await databases.getDocument(DB_ID, 'worker_profiles', workerProfileId).catch(() => null);
  if (!worker) return { status: 404, body: { error: 'worker profile not found' } };
  if (worker.userId !== caller.$id) {
    return { status: 403, body: { error: 'you can only withdraw your own wallet' } };
  }

  const amount = worker.walletBalance || 0;
  if (amount <= 0) return { status: 400, body: { error: 'nothing to withdraw' } };

  await databases.updateDocument(DB_ID, 'worker_profiles', workerProfileId, { walletBalance: 0 });

  await databases.createDocument(
    DB_ID,
    'wallet_withdrawals',
    'unique()',
    { workerId: worker.userId, amount, status: 'completed' },
    [Permission.read(Role.user(callerAuthId))]
  ).catch(() => {});

  return { status: 200, body: { ok: true, withdrawn: amount } };
};
