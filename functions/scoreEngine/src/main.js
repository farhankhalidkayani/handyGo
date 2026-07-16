// scoreEngine — §9.10: A6. Scheduled (daily). Deterministic weighted formulas — transparent
// and defensible in an FYP viva, no LLM involved.
const { Query } = require('node-appwrite');
const { getDatabases, DB_ID } = require('./lib/appwriteClient');

function clamp(n, lo = 0, hi = 100) {
  return Math.max(lo, Math.min(hi, Math.round(n)));
}

module.exports = async ({ res, log, error }) => {
  const databases = getDatabases();

  // Customers
  const customers = await databases.listDocuments(DB_ID, 'customer_profiles', [Query.limit(500)]);
  for (const c of customers.documents) {
    const bookings = await databases.listDocuments(DB_ID, 'bookings', [
      Query.equal('customerId', c.userId),
      Query.limit(500),
    ]);
    const cancellations = bookings.documents.filter((b) => b.status === 'cancelled').length;
    const fraudReports = await databases.listDocuments(DB_ID, 'fraud_reports', [
      Query.equal('accusedId', c.userId),
      Query.limit(500),
    ]);
    const sosMisuse = 0; // requires manual admin tagging of false SOS reports — left at 0 until that exists
    const riskScore = clamp(100 - (cancellations * 8 + fraudReports.total * 20 + sosMisuse * 15));
    await databases.updateDocument(DB_ID, 'users', c.userId, { riskScore }).catch((e) => error(e.message));
  }

  // Workers
  const workers = await databases.listDocuments(DB_ID, 'worker_profiles', [Query.limit(500)]);
  for (const w of workers.documents) {
    const bookings = await databases.listDocuments(DB_ID, 'bookings', [
      Query.equal('workerId', w.userId),
      Query.limit(500),
    ]);
    const total = bookings.documents.length || 1;
    const completed = bookings.documents.filter((b) => b.status === 'completed').length;
    const completionRate = completed / total;
    const onTimeRate = 0.9; // placeholder until arrival-vs-ETA tracking is wired up
    const complaints = await databases.listDocuments(DB_ID, 'fraud_reports', [
      Query.equal('accusedId', w.userId),
      Query.limit(500),
    ]);
    const performanceScore = clamp(
      (w.rating || 0) * 15 + completionRate * 40 + onTimeRate * 25 - complaints.total * 10
    );
    await databases.updateDocument(DB_ID, 'worker_profiles', w.$id, { performanceScore }).catch((e) => error(e.message));
  }

  log(`scoreEngine: recomputed ${customers.total} customer + ${workers.total} worker scores`);
  return res.json({ ok: true, customers: customers.total, workers: workers.total });
};
