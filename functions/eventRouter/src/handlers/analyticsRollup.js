// §9.1/A7. Rules-based aggregation for admin dashboards; LLM narrative generation is left to
// the Admin Panel UI, so this stays cheap, deterministic and always-on.
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');

function startOfToday() {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

module.exports = async function analyticsRollup({ log }) {
  const databases = getDatabases();
  const today = startOfToday();
  const bookingsRes = await databases.listDocuments(DB_ID, 'bookings', [Query.limit(2000)]);
  const todaysBookings = bookingsRes.documents.filter((b) => new Date(b.$createdAt) >= today);

  const completed = todaysBookings.filter((b) => b.status === 'completed');
  const cancelled = todaysBookings.filter((b) => b.status === 'cancelled');

  const revenue = completed.reduce((sum, b) => sum + (b.finalQuote || 0) + (b.additionalCharges || 0), 0);
  const avgRating = completed.length
    ? completed.reduce((s, b) => s + (b.ratingGiven || 0), 0) / completed.length
    : 0;

  const demandByCategory = {};
  for (const b of todaysBookings) {
    demandByCategory[b.categoryId] = (demandByCategory[b.categoryId] || 0) + 1;
  }

  const cancellationReasons = {};
  for (const b of cancelled) {
    const reason = b.reviewText || 'unspecified';
    cancellationReasons[reason] = (cancellationReasons[reason] || 0) + 1;
  }

  const doc = {
    date: today.toISOString(),
    totalBookings: todaysBookings.length,
    completed: completed.length,
    cancelled: cancelled.length,
    revenue,
    avgRating,
    demandByCategory: JSON.stringify(demandByCategory),
    workerShortageAreas: JSON.stringify({}), // needs geographic clustering — out of scope for the FYP MVP
    cancellationReasons: JSON.stringify(cancellationReasons),
  };

  const existing = await databases
    .listDocuments(DB_ID, 'analytics_daily', [Query.equal('date', today.toISOString())])
    .catch(() => ({ documents: [] }));

  if (existing.documents[0]) {
    await databases.updateDocument(DB_ID, 'analytics_daily', existing.documents[0].$id, doc);
  } else {
    await databases.createDocument(DB_ID, 'analytics_daily', 'unique()', doc);
  }

  log(`analyticsRollup: ${doc.totalBookings} bookings, revenue ${doc.revenue}`);
  return doc;
};
