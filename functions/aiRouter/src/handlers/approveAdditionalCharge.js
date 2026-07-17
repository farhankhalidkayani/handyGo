// Customer approves (or rejects) a pending additional-charge request. Reads the amount back
// from bookings.pendingAdditionalCharge (set server-side by requestAdditionalCharge) rather
// than accepting an amount from the client — see requestAdditionalCharge.js for why.
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

module.exports = async function approveAdditionalCharge(body) {
  const { bookingId, customerId, approve } = body;
  if (!bookingId || !customerId || typeof approve !== 'boolean') {
    return { status: 400, body: { error: 'bookingId, customerId, approve (boolean) are required' } };
  }

  const databases = getDatabases();
  const booking = await databases.getDocument(DB_ID, 'bookings', bookingId).catch(() => null);
  if (!booking) return { status: 404, body: { error: 'booking not found' } };
  if (booking.customerId !== customerId) {
    return { status: 403, body: { error: 'booking does not belong to this customer' } };
  }
  if (!booking.pendingAdditionalCharge) {
    return { status: 409, body: { error: 'no pending additional charge on this booking' } };
  }

  const update = approve
    ? {
        additionalCharges: (booking.additionalCharges || 0) + booking.pendingAdditionalCharge,
        pendingAdditionalCharge: 0,
        pendingAdditionalChargeReason: '',
      }
    : { pendingAdditionalCharge: 0, pendingAdditionalChargeReason: '' };

  await databases.updateDocument(DB_ID, 'bookings', bookingId, update);

  if (booking.workerId) {
    await databases.createDocument(DB_ID, 'notifications', 'unique()', {
      userId: booking.workerId,
      role: 'worker',
      type: 'additional_charge_decision',
      title: approve ? 'Customer approved the additional charge' : 'Customer declined the additional charge',
      body: '',
      bookingId,
      read: false,
    }).catch(() => {});
  }

  return { status: 200, body: { ok: true, approved: approve, additionalCharges: update.additionalCharges ?? booking.additionalCharges } };
};
