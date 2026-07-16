// lib/parseBody.js — Appwrite's Node runtime hands `req.body` back already parsed as an
// object when content-type is JSON, but as a raw string for other/older clients. Handle both.
function parseBody(req) {
  const raw = req.body;
  if (raw == null || raw === '') return {};
  if (typeof raw === 'object') return raw;
  return JSON.parse(raw);
}

module.exports = { parseBody };
