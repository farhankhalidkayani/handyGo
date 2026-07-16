// §9.8 W5: ETA via OSRM (with a straight-line fallback if OSRM is unreachable, per the Risk
// Register §15), plus a rules-based schedule overlap check.
const OSRM_URL = process.env.OSRM_URL || 'https://router.project-osrm.org';

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

async function etaMinutes(from, to) {
  try {
    const url = `${OSRM_URL}/route/v1/driving/${from.lng},${from.lat};${to.lng},${to.lat}?overview=false`;
    const r = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!r.ok) throw new Error(`OSRM HTTP ${r.status}`);
    const data = await r.json();
    const seconds = data.routes?.[0]?.duration;
    if (typeof seconds !== 'number') throw new Error('no route');
    return { mins: Math.round(seconds / 60), source: 'osrm' };
  } catch {
    const dist = haversineKm(from, to);
    return { mins: Math.round(dist / 0.4), source: 'straight-line-fallback' };
  }
}

module.exports = async function routePlanner(body) {
  const { workerLat, workerLng, jobs = [] } = body;
  if (workerLat === undefined || workerLng === undefined) {
    return { status: 400, body: { error: 'workerLat/workerLng required' } };
  }

  let cursor = { lat: workerLat, lng: workerLng };
  let clock = Date.now();
  const ordered = [];
  const remaining = [...jobs];

  while (remaining.length) {
    const withEta = await Promise.all(
      remaining.map(async (j, idx) => ({ idx, ...(await etaMinutes(cursor, { lat: j.lat, lng: j.lng })) }))
    );
    withEta.sort((a, b) => a.mins - b.mins);
    const next = withEta[0];
    const job = remaining.splice(next.idx, 1)[0];
    const arriveAt = clock + next.mins * 60000;
    ordered.push({ ...job, etaMins: next.mins, etaSource: next.source, estimatedArrival: new Date(arriveAt).toISOString() });
    clock = arriveAt + (job.durationMins || 60) * 60000;
    cursor = { lat: job.lat, lng: job.lng };
  }

  const conflicts = [];
  for (let i = 1; i < ordered.length; i++) {
    if (ordered[i].scheduledAt) {
      const scheduled = new Date(ordered[i].scheduledAt).getTime();
      const arrival = new Date(ordered[i].estimatedArrival).getTime();
      if (arrival > scheduled + 15 * 60000) {
        conflicts.push({ bookingId: ordered[i].bookingId, lateByMins: Math.round((arrival - scheduled) / 60000) });
      }
    }
  }

  return { status: 200, body: { route: ordered, conflicts } };
};
