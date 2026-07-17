// submitRating — customer rates a completed booking. Recomputes the worker's simple average
// rating server-side (bookings.ratingGiven is server-only per §11, so this can't be a direct
// client update).
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

module.exports = async function submitRating(body) {
  const { bookingId, customerId, rating, reviewText } = body;
  if (!bookingId || !customerId || typeof rating !== 'number' || rating < 1 || rating > 5) {
    return { status: 400, body: { error: 'bookingId, customerId, rating (1-5) are required' } };
  }

  const databases = getDatabases();
  const booking = await databases.getDocument(DB_ID, 'bookings', bookingId).catch(() => null);
  if (!booking) return { status: 404, body: { error: 'booking not found' } };
  if (booking.customerId !== customerId) {
    return { status: 403, body: { error: 'booking does not belong to this customer' } };
  }
  if (booking.status !== 'completed') {
    return { status: 409, body: { error: 'can only rate a completed booking' } };
  }
  if (booking.ratingGiven) {
    return { status: 409, body: { error: 'booking already rated' } };
  }

  await databases.updateDocument(DB_ID, 'bookings', bookingId, {
    ratingGiven: Math.round(rating),
    reviewText: reviewText || '',
  });

  if (booking.workerId) {
    // booking.workerId references users.$id (like worker_profiles.userId), not the
    // worker_profiles document's own $id — look it up before updating.
    const workerProfiles = await databases.listDocuments(DB_ID, 'worker_profiles', [
      Query.equal('userId', booking.workerId),
      Query.limit(1),
    ]);
    const workerProfile = workerProfiles.documents[0];
    if (workerProfile) {
      const priorBookings = await databases.listDocuments(DB_ID, 'bookings', [
        Query.equal('workerId', booking.workerId),
        Query.equal('status', 'completed'),
        Query.isNotNull('ratingGiven'),
        Query.limit(500),
      ]);
      const ratings = priorBookings.documents.map((b) => b.ratingGiven).filter((r) => typeof r === 'number');
      ratings.push(Math.round(rating));
      const avg = ratings.reduce((a, b) => a + b, 0) / ratings.length;
      await databases.updateDocument(DB_ID, 'worker_profiles', workerProfile.$id, {
        rating: Math.round(avg * 10) / 10,
      }).catch(() => {});
    }
  }

  return { status: 200, body: { ok: true } };
};
