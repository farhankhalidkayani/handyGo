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
  const { bookingId, nextStatus, changedByRole, changedById, note, otp, workSummary } = body;
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

  // SOS Control Center "Pause Booking"/"Block Payment" (plan §10.3) — an admin-paused booking
  // can still be cancelled (so the customer/worker isn't stuck), but can't otherwise progress;
  // a payment-blocked booking can't reach `completed` (settlement) until the block is lifted.
  if (booking.paused && nextStatus !== 'cancelled') {
    return { status: 409, body: { error: 'booking is paused by an admin — cancel or wait for it to be resumed' } };
  }
  if (booking.paymentBlocked && nextStatus === 'completed') {
    return { status: 409, body: { error: 'payment is blocked by an admin for this booking' } };
  }

  if (nextStatus === 'service_started') {
    if (!otp || otp !== booking.otp) {
      return { status: 403, body: { error: 'invalid or missing OTP' } };
    }
  }

  const update = { status: nextStatus };
  // workSummary (plan §9.8 W6, from workerAssist mode=summary) is server-only same as status
  // — a worker can only set it by passing through this transition, never a direct update.
  if (nextStatus === 'completion_requested' && workSummary) update.workSummary = workSummary;
  await databases.updateDocument(DB_ID, 'bookings', bookingId, update);
  await databases.createDocument(DB_ID, 'booking_status_history', 'unique()', {
    bookingId,
    status: nextStatus,
    changedByRole,
    changedById: changedById || '',
    note: note || '',
    timestamp: new Date().toISOString(),
  }).catch(() => {});

  // Real online-payment settlement is out of scope for the FYP (plan §1) — completion is
  // treated as an instant COD settlement, recorded here since transactions.commission/
  // netToWorker are server-only fields (§11).
  if (nextStatus === 'completed') {
    const serviceCharges = booking.finalQuote || 0;
    const materialCharges = booking.additionalCharges || 0;
    const total = serviceCharges + materialCharges;
    const commission = Math.round(total * 0.15 * 100) / 100;
    await databases.createDocument(DB_ID, 'transactions', 'unique()', {
      bookingId,
      customerId: booking.customerId,
      workerId: booking.workerId || '',
      serviceCharges,
      materialCharges,
      platformFee: commission,
      discount: 0,
      total,
      method: 'cod',
      status: 'paid',
      commission,
      netToWorker: Math.round((total - commission) * 100) / 100,
    }).catch(() => {});
  }

  return { status: 200, body: { ok: true, status: nextStatus } };
};
