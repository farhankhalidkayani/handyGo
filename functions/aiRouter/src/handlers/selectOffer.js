// selectOffer — customer accepts one of the worker_offers on their booking (plan §7:
// offers_received -> worker_selected). Runs server-side so the client never needs "update"
// permission on bookings/worker_offers: this accepts the chosen offer, expires the rest, sets
// booking.workerId/finalQuote, and transitions status — all in one atomic-ish server call.
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

const TRANSITIONS_FROM = ['offers_received', 'searching_workers'];

module.exports = async function selectOffer(body) {
  const { bookingId, offerId, customerId } = body;
  if (!bookingId || !offerId || !customerId) {
    return { status: 400, body: { error: 'bookingId, offerId, customerId are required' } };
  }

  const databases = getDatabases();
  const booking = await databases.getDocument(DB_ID, 'bookings', bookingId).catch(() => null);
  if (!booking) return { status: 404, body: { error: 'booking not found' } };
  if (booking.customerId !== customerId) {
    return { status: 403, body: { error: 'booking does not belong to this customer' } };
  }
  if (!TRANSITIONS_FROM.includes(booking.status)) {
    return { status: 409, body: { error: `cannot select an offer from status "${booking.status}"` } };
  }

  const offer = await databases.getDocument(DB_ID, 'worker_offers', offerId).catch(() => null);
  if (!offer || offer.bookingId !== bookingId) {
    return { status: 404, body: { error: 'offer not found for this booking' } };
  }

  const allOffers = await databases.listDocuments(DB_ID, 'worker_offers', [
    Query.equal('bookingId', bookingId),
    Query.limit(100),
  ]);
  for (const o of allOffers.documents) {
    if (o.$id === offerId) continue;
    await databases.updateDocument(DB_ID, 'worker_offers', o.$id, { status: 'rejected' }).catch(() => {});
  }
  await databases.updateDocument(DB_ID, 'worker_offers', offerId, { status: 'accepted' });

  await databases.updateDocument(DB_ID, 'bookings', bookingId, {
    workerId: offer.workerId,
    finalQuote: offer.quote,
    status: 'worker_selected',
  });
  await databases.createDocument(DB_ID, 'booking_status_history', 'unique()', {
    bookingId,
    status: 'worker_selected',
    changedByRole: 'customer',
    changedById: customerId,
    note: `Selected offer ${offerId}`,
    timestamp: new Date().toISOString(),
  }).catch(() => {});

  await databases.createDocument(DB_ID, 'notifications', 'unique()', {
    userId: offer.workerId,
    role: 'worker',
    type: 'offer_accepted',
    title: 'Your offer was accepted',
    body: 'Confirm the job to start navigation.',
    bookingId,
    read: false,
  }).catch(() => {});

  return { status: 200, body: { ok: true, bookingId, workerId: offer.workerId, status: 'worker_selected' } };
};
