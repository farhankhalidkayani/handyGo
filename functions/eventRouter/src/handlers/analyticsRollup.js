// §9.1/A7. Rules-based aggregation for admin dashboards, plus a short LLM-authored narrative
// on top (demand forecast / shortage / cancellation insight) — read-only and advisory only,
// never writes any decision field, so it stays inside the §8.3 governance rule (AI recommends,
// admin decides) even though this is the one AI feature with no explicit decision buttons.
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('../lib/appwriteClient');
const { askLLM } = require('../lib/llm');

function startOfToday() {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

// ~0.05deg is roughly 5.5km at the equator — coarse enough that a handful of bookings/workers
// land in the same cell, fine enough to distinguish neighborhoods within a city. Pure
// client-side-computable rules, no geo library or paid API needed.
const GRID_SIZE = 0.05;
function gridKey(lat, lng) {
  return `${Math.round(lat / GRID_SIZE)}:${Math.round(lng / GRID_SIZE)}`;
}
function gridCenter(key) {
  const [gy, gx] = key.split(':').map(Number);
  return { lat: gy * GRID_SIZE, lng: gx * GRID_SIZE };
}

// Worker-shortage areas (plan §12/A7): grid cells with real demand today but few/no online
// workers nearby (same cell or an adjacent one, so a worker just across a cell boundary still
// counts as coverage).
async function findShortageAreas(databases, todaysBookings) {
  const demandCells = {};
  for (const b of todaysBookings) {
    if (!b.lat || !b.lng) continue;
    demandCells[gridKey(b.lat, b.lng)] = (demandCells[gridKey(b.lat, b.lng)] || 0) + 1;
  }
  if (!Object.keys(demandCells).length) return {};

  const workersRes = await databases.listDocuments(DB_ID, 'worker_profiles', [
    Query.equal('availability', 'online'),
    Query.limit(500),
  ]);
  const workerCells = {};
  for (const w of workersRes.documents) {
    if (!w.currentLat || !w.currentLng) continue;
    const key = gridKey(w.currentLat, w.currentLng);
    workerCells[key] = (workerCells[key] || 0) + 1;
  }

  const neighborsOf = (key) => {
    const [gy, gx] = key.split(':').map(Number);
    const keys = [];
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) keys.push(`${gy + dy}:${gx + dx}`);
    }
    return keys;
  };

  const shortages = {};
  for (const [key, demand] of Object.entries(demandCells)) {
    const nearbyWorkers = neighborsOf(key).reduce((sum, k) => sum + (workerCells[k] || 0), 0);
    if (demand >= 2 && nearbyWorkers === 0) {
      shortages[key] = { ...gridCenter(key), demand, nearbyWorkers };
    }
  }
  return shortages;
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

  // Admin UI already maps categoryId -> name itself for the chart (analytics_body.dart), but
  // the AI narrative text below quotes this object directly — without translating ids to
  // names here too, the LLM writes sentences like "category 6a58f9..." instead of "Plumbing".
  const categoriesRes = await databases.listDocuments(DB_ID, 'service_categories', [Query.limit(100)]);
  const categoryNames = Object.fromEntries(categoriesRes.documents.map((c) => [c.$id, c.name]));
  const demandByCategoryName = Object.fromEntries(
    Object.entries(demandByCategory).map(([id, count]) => [categoryNames[id] || id, count])
  );

  const cancellationReasons = {};
  for (const b of cancelled) {
    const reason = b.reviewText || 'unspecified';
    cancellationReasons[reason] = (cancellationReasons[reason] || 0) + 1;
  }

  const shortageAreas = await findShortageAreas(databases, todaysBookings);

  const sys = `You are HandyGo's admin analytics assistant. Given today's raw booking numbers,
write a 2-3 sentence recommendation card: call out anything that needs attention (a spike in
cancellations, low completion rate, a category with unusually high demand) and one concrete
suggestion. Be specific with the numbers given — always refer to categories by their name, never
by an id. If nothing stands out, just say things look normal. Never mention refunds, bans, or
suspensions — this is informational only, admins make those decisions elsewhere.`;
  const narrativeOut = await askLLM(sys, JSON.stringify({
    totalBookings: todaysBookings.length,
    completed: completed.length,
    cancelled: cancelled.length,
    revenue,
    avgRating,
    demandByCategory: demandByCategoryName,
    cancellationReasons,
    shortageAreaCount: Object.keys(shortageAreas).length,
  }));
  const aiNarrative = narrativeOut.tier === 'llm' && narrativeOut.text
    ? narrativeOut.text
    : `${todaysBookings.length} bookings today, ${completed.length} completed, ${cancelled.length} cancelled.`;

  const doc = {
    date: today.toISOString(),
    totalBookings: todaysBookings.length,
    completed: completed.length,
    cancelled: cancelled.length,
    revenue,
    avgRating,
    demandByCategory: JSON.stringify(demandByCategory),
    workerShortageAreas: JSON.stringify(shortageAreas),
    cancellationReasons: JSON.stringify(cancellationReasons),
    aiNarrative,
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
