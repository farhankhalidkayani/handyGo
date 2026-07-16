// §9.7: C7/A2. Fires on worker_offers.create. Pure rules: flags quotes far above the
// category band, and warns when a worker's live GPS looks inconsistent with their declared
// service area (possible spoofing / subcontracting fraud signal).
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

module.exports = async function priceGuard(offer, { error }) {
  const databases = getDatabases();
  const booking = await databases.getDocument(DB_ID, 'bookings', offer.bookingId).catch(() => null);
  if (!booking) return { ok: false, reason: 'booking not found' };

  const category = await databases.getDocument(DB_ID, 'service_categories', booking.categoryId).catch(() => null);
  const worker = await databases.getDocument(DB_ID, 'worker_profiles', offer.workerId).catch(() => null);

  let flagged = false;
  const reasons = [];

  if (category && offer.quote > category.basePriceMax * 1.8) {
    flagged = true;
    reasons.push('Quote far above typical range');
  }

  if (worker && worker.currentLat != null && worker.serviceAreaLat != null) {
    const dist = haversineKm(
      { lat: worker.currentLat, lng: worker.currentLng },
      { lat: worker.serviceAreaLat, lng: worker.serviceAreaLng }
    );
    if (dist > (worker.serviceRadiusKm || 8) * 2) {
      reasons.push('Worker location looks inconsistent with declared service area');
      await databases.createDocument(DB_ID, 'notifications', 'unique()', {
        userId: booking.customerId,
        role: 'customer',
        type: 'location_warning',
        title: 'Location check',
        body: 'Worker location looks inconsistent with their declared service area.',
        bookingId: booking.$id,
        read: false,
      }).catch((e) => error(`notification write failed: ${e.message}`));
    }
  }

  if (flagged) {
    await databases.updateDocument(DB_ID, 'worker_offers', offer.$id, { flaggedSuspicious: true });
  }

  return { ok: true, flagged, reasons };
};
