// §7/§7.1/§11. Enforces the booking state machine guard table server-side so no client can
// jump statuses illegally (e.g. a worker can't set `service_started` without a valid OTP).
// This is the ONLY place `bookings.status` may be written from — clients must never write
// status directly (§11 server-only writes for sensitive fields).
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

const TRANSITIONS = {
  draft: ['searching_workers'],
  searching_workers: ['offers_received', 'cancelled'],
  offers_received: ['worker_selected', 'cancelled'],
  worker_selected: ['confirmed', 'cancelled'],
  confirmed: ['worker_on_the_way', 'cancelled'],
  worker_on_the_way: ['worker_arrived'],
  worker_arrived: ['service_started'],
  service_started: ['in_progress'],
  in_progress: ['completion_requested'],
  completion_requested: ['payment_pending'],
  payment_pending: ['completed'],
  disputed: ['refunded', 'completed'],
};
const TERMINAL = ['completed', 'cancelled', 'refunded'];

module.exports = async function transitionBooking(body) {
  const { bookingId, nextStatus, changedByRole, changedById, note, otp } = body;
  if (!bookingId || !nextStatus || !changedByRole) {
    return { status: 400, body: { error: 'bookingId, nextStatus, changedByRole are required' } };
  }

  const databases = getDatabases();
  const booking = await databases.getDocument(DB_ID, 'bookings', bookingId).catch(() => null);
  if (!booking) return { status: 404, body: { error: 'booking not found' } };

  const from = booking.status;
  const allowed =
    TRANSITIONS[from]?.includes(nextStatus) ||
    (!TERMINAL.includes(from) && (nextStatus === 'disputed' || nextStatus === 'cancelled'));
  if (!allowed) {
    return { status: 409, body: { error: `illegal transition ${from} -> ${nextStatus}` } };
  }

  if (nextStatus === 'service_started') {
    if (!otp || otp !== booking.otp) {
      return { status: 403, body: { error: 'invalid or missing OTP' } };
    }
  }

  await databases.updateDocument(DB_ID, 'bookings', bookingId, { status: nextStatus });
  await databases.createDocument(DB_ID, 'booking_status_history', 'unique()', {
    bookingId,
    status: nextStatus,
    changedByRole,
    changedById: changedById || '',
    note: note || '',
    timestamp: new Date().toISOString(),
  }).catch(() => {});

  return { status: 200, body: { ok: true, status: nextStatus } };
};
