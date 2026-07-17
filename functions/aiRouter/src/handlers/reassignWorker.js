// Admin-only: reassign a booking to a different worker (plan §12 Admin "Booking management"
// checklist) — e.g. the original worker went offline/unresponsive mid-job. Authorization
// mirrors updateWorkerVerification.js: gated on the caller's real x-appwrite-user-id, never a
// client-supplied admin flag.
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

// Reassignment only makes sense before the job is actually done — once completed/cancelled/
// refunded/disputed, this isn't a "wrong worker" situation anymore, it's a dispute/refund one.
const REASSIGNABLE_STATUSES = [
  'worker_selected',
  'confirmed',
  'worker_on_the_way',
  'worker_arrived',
  'service_started',
  'in_progress',
];

module.exports = async function reassignWorker(body, { req }) {
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

  const { bookingId, newWorkerId, reason } = body;
  if (!bookingId || !newWorkerId) {
    return { status: 400, body: { error: 'bookingId and newWorkerId are required' } };
  }

  const booking = await databases.getDocument(DB_ID, 'bookings', bookingId).catch(() => null);
  if (!booking) return { status: 404, body: { error: 'booking not found' } };
  if (!REASSIGNABLE_STATUSES.includes(booking.status)) {
    return { status: 409, body: { error: `cannot reassign a booking in status "${booking.status}"` } };
  }

  const newWorkerProfile = await databases.listDocuments(DB_ID, 'worker_profiles', [
    Query.equal('userId', newWorkerId),
    Query.limit(1),
  ]);
  if (!newWorkerProfile.documents[0]) {
    return { status: 404, body: { error: 'new worker has no worker_profiles document' } };
  }

  const oldWorkerId = booking.workerId;
  await databases.updateDocument(DB_ID, 'bookings', bookingId, {
    workerId: newWorkerId,
    // A reassignment restarts the on-the-way/OTP sequence for the new worker — they haven't
    // actually confirmed or traveled yet, whatever the old worker's progress was.
    status: 'worker_selected',
  });
  await databases.createDocument(DB_ID, 'booking_status_history', 'unique()', {
    bookingId,
    status: 'worker_selected',
    changedByRole: 'admin',
    changedById: callerAuthId,
    note: reason ? `Reassigned by admin: ${reason}` : 'Reassigned by admin',
    timestamp: new Date().toISOString(),
  }).catch(() => {});

  if (oldWorkerId) {
    await databases.createDocument(DB_ID, 'notifications', 'unique()', {
      userId: oldWorkerId,
      role: 'worker',
      type: 'booking_reassigned',
      title: 'Booking reassigned',
      body: reason || 'An admin has reassigned this job to another worker.',
      bookingId,
      read: false,
    }).catch(() => {});
  }
  await databases.createDocument(DB_ID, 'notifications', 'unique()', {
    userId: newWorkerId,
    role: 'worker',
    type: 'booking_reassigned',
    title: 'New job assigned to you',
    body: reason || 'An admin has assigned this job to you.',
    bookingId,
    read: false,
  }).catch(() => {});

  return { status: 200, body: { ok: true, bookingId, workerId: newWorkerId } };
};
