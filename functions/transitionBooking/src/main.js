// transitionBooking — §7/§7.1/§11. Enforces the booking state machine guard table server-side
// so no client can jump statuses illegally (e.g. a worker can't set `service_started` without
// a valid OTP). This is the ONLY place `bookings.status` may be written from — clients must
// never write status directly (§11 server-only writes for sensitive fields).
const { getDatabases, DB_ID } = require('./lib/appwriteClient');

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
// Any active (non-terminal) status may also go to disputed/cancelled via admin/customer/worker.
const TERMINAL = ['completed', 'cancelled', 'refunded'];

module.exports = async ({ req, res, error }) => {
  let body;
  try {
    body = JSON.parse(req.body || '{}');
  } catch {
    return res.json({ error: 'invalid JSON body' }, 400);
  }
  const { bookingId, nextStatus, changedByRole, changedById, note, otp } = body;
  if (!bookingId || !nextStatus || !changedByRole) {
    return res.json({ error: 'bookingId, nextStatus, changedByRole are required' }, 400);
  }

  const databases = getDatabases();
  const booking = await databases.getDocument(DB_ID, 'bookings', bookingId).catch(() => null);
  if (!booking) return res.json({ error: 'booking not found' }, 404);

  const from = booking.status;
  const allowed =
    TRANSITIONS[from]?.includes(nextStatus) ||
    (!TERMINAL.includes(from) && (nextStatus === 'disputed' || nextStatus === 'cancelled'));
  if (!allowed) {
    return res.json({ error: `illegal transition ${from} -> ${nextStatus}` }, 409);
  }

  if (nextStatus === 'service_started') {
    if (!otp || otp !== booking.otp) {
      return res.json({ error: 'invalid or missing OTP' }, 403);
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
  }).catch((e) => error(`status history write failed: ${e.message}`));

  return res.json({ ok: true, status: nextStatus });
};
