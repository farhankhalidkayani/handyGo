#!/usr/bin/env node
// functions/setup_admin_team.js — one-off, idempotent fix for a real bug found while auditing
// permissions: `analytics_daily`/`ai_logs` were declared with `read("team:admin")` in
// appwrite.json from the start, but no Appwrite Team named "admin" was ever created — meaning
// a real admin's own client session could never actually read analytics_daily (only the API
// key could, which bypasses all permission checks and masked this in earlier testing).
// Creates the "admin" team if missing, and adds every `users` document with role=admin as a
// member. Safe to re-run any time (e.g. after seeding a new admin account).
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const sdk = require('node-appwrite');

const ENDPOINT = process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1';
const PROJECT = process.env.APPWRITE_PROJECT;
const API_KEY = process.env.APPWRITE_API_KEY;
const DB_ID = process.env.APPWRITE_DB || 'handygo';

const client = new sdk.Client().setEndpoint(ENDPOINT).setProject(PROJECT).setKey(API_KEY);
const databases = new sdk.Databases(client);
const teams = new sdk.Teams(client);
const users = new sdk.Users(client);

async function ensureAdminTeam() {
  await teams.get('admin').catch(async (e) => {
    if (e.code !== 404) throw e;
    await teams.create('admin', 'admin');
    console.log('Created team "admin"');
  });
}

async function addAdminMembers() {
  const adminUsersRes = await databases.listDocuments(DB_ID, 'users', [
    sdk.Query.equal('role', 'admin'),
    sdk.Query.limit(100),
  ]);
  const existingMembers = await teams.listMemberships('admin');
  const existingUserIds = new Set(existingMembers.memberships.map((m) => m.userId));

  for (const u of adminUsersRes.documents) {
    if (existingUserIds.has(u.authId)) {
      console.log(`  = ${u.email} already a team member`);
      continue;
    }
    const authUser = await users.get(u.authId).catch(() => null);
    if (!authUser) {
      console.error(`  ! ${u.email}: no matching Auth user for authId ${u.authId}`);
      continue;
    }
    await teams.createMembership('admin', ['admin'], undefined, u.authId).then(
      () => console.log(`  + added ${u.email} to team "admin"`),
      (e) => console.error(`  ! ${u.email}: ${e.message}`)
    );
  }
}

(async () => {
  await ensureAdminTeam();
  await addAdminMembers();
  console.log('Done.');
})().catch((e) => {
  console.error('FAILED:', e.message);
  process.exit(1);
});
