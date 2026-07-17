// Worker requests extra payment mid-job for unplanned materials (plan §14.2 demo script:
// "worker requests Rs. 500 material -> customer approves"). Stores the request on the booking
// itself (pendingAdditionalCharge/-Reason) rather than trusting a client-supplied amount at
// approval time — approveAdditionalCharge.js reads this back instead of accepting a number
// from the customer's client, so a customer can't quietly approve a different amount than
// what was actually requested.
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

module.exports = async function requestAdditionalCharge(body) {
  const { bookingId, workerId, amount, reason } = body;
  if (!bookingId || !workerId || typeof amount !== 'number' || amount <= 0) {
    return { status: 400, body: { error: 'bookingId, workerId, amount (>0) are required' } };
  }

  const databases = getDatabases();
  const booking = await databases.getDocument(DB_ID, 'bookings', bookingId).catch(() => null);
  if (!booking) return { status: 404, body: { error: 'booking not found' } };
  if (booking.workerId !== workerId) {
    return { status: 403, body: { error: 'booking is not assigned to this worker' } };
  }
  if (booking.status !== 'in_progress') {
    return { status: 409, body: { error: 'can only request an additional charge while in_progress' } };
  }

  await databases.updateDocument(DB_ID, 'bookings', bookingId, {
    pendingAdditionalCharge: amount,
    pendingAdditionalChargeReason: reason || '',
  });

  await databases.createDocument(DB_ID, 'notifications', 'unique()', {
    userId: booking.customerId,
    role: 'customer',
    type: 'additional_charge_request',
    title: `Worker requests Rs. ${amount} for materials`,
    body: reason || '',
    bookingId,
    read: false,
  }).catch(() => {});

  return { status: 200, body: { ok: true, pendingAdditionalCharge: amount } };
};
