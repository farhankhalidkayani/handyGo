// §9.6: C5/C6. Pure rules — fast, free, explainable geo/skill ranking. Best-match = top
// blended score, NOT lowest price (plan's explicit rule).
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

function haversineKm(a, b) {
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const lat1 = (a.lat * Math.PI) / 180;
  const lat2 = (b.lat * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// C6: multi-criteria comparison across the offers already sent for one booking — best price /
// fastest / top rated are simple mins/maxes; best match is the same blended score as C5,
// persisted onto the winning worker_offers doc so every viewer (customer/admin) sees one answer.
async function compareOffers(body) {
  const { bookingId } = body;
  if (!bookingId) return { status: 400, body: { error: 'bookingId is required' } };

  const databases = getDatabases();
  const offersRes = await databases.listDocuments(DB_ID, 'worker_offers', [
    Query.equal('bookingId', bookingId),
    Query.equal('status', 'sent'),
    Query.limit(100),
  ]);
  const offers = offersRes.documents;
  if (!offers.length) return { status: 200, body: { bookingId, offers: [] } };

  const workersRes = await databases.listDocuments(DB_ID, 'worker_profiles', [
    Query.equal('userId', offers.map((o) => o.workerId)),
    Query.limit(100),
  ]);
  const workerByUserId = new Map(workersRes.documents.map((w) => [w.userId, w]));

  const scored = offers.map((o) => {
    const worker = workerByUserId.get(o.workerId);
    const rating = worker?.rating || 0;
    const jobsCompleted = worker?.jobsCompleted || 0;
    const dist = o.distanceKm || 0;
    return {
      offerId: o.$id,
      rating,
      score: rating * 20 - dist * 3 + Math.min(jobsCompleted, 50) * 0.4,
    };
  });
  scored.sort((a, b) => b.score - a.score);
  const bestMatchId = scored[0].offerId;
  const topRatedId = [...scored].sort((a, b) => b.rating - a.rating)[0].offerId;

  await Promise.all(
    offers.map((o) =>
      databases
        .updateDocument(DB_ID, 'worker_offers', o.$id, { isBestMatch: o.$id === bestMatchId })
        .catch(() => {})
    )
  );

  return { status: 200, body: { bookingId, bestMatchOfferId: bestMatchId, topRatedOfferId: topRatedId } };
}

module.exports = async function recommendWorkers(body) {
  if (body.mode === 'compareOffers') return compareOffers(body);

  const { bookingId, categoryName, lat, lng, radiusKm = 8 } = body;
  if (lat === undefined || lng === undefined || !categoryName) {
    return { status: 400, body: { error: 'categoryName, lat, lng are required' } };
  }

  const databases = getDatabases();
  const workersRes = await databases.listDocuments(DB_ID, 'worker_profiles', [
    Query.equal('availability', 'online'),
    Query.equal('verificationStatus', 'approved'),
    Query.limit(200),
  ]);

  const scored = workersRes.documents
    .filter((w) => (w.skills || []).includes(categoryName))
    .map((w) => {
      const dist = haversineKm({ lat, lng }, { lat: w.currentLat, lng: w.currentLng });
      return {
        workerId: w.userId,
        dist,
        etaMins: Math.round(dist / 0.4),
        rating: w.rating || 0,
        jobsCompleted: w.jobsCompleted || 0,
        score: (w.rating || 0) * 20 - dist * 3 + Math.min(w.jobsCompleted || 0, 50) * 0.4,
      };
    })
    .filter((x) => x.dist <= radiusKm)
    .sort((a, b) => b.score - a.score);

  if (scored[0]) scored[0].isBestMatch = true;

  return { status: 200, body: { bookingId, candidates: scored } };
};
