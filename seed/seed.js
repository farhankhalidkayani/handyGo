#!/usr/bin/env node
// seed/seed.js — populates service_categories and demo accounts (§14.1) into an already
// provisioned Appwrite project (run `node seed/provision.js` first).
// Usage: node seed/seed.js
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const sdk = require('node-appwrite');

const ENDPOINT = process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1';
const PROJECT = process.env.APPWRITE_PROJECT;
const API_KEY = process.env.APPWRITE_API_KEY;
const DB_ID = process.env.APPWRITE_DB || 'handygo';

if (!PROJECT || !API_KEY) {
  console.error('APPWRITE_PROJECT and APPWRITE_API_KEY must be set (see .env.example)');
  process.exit(1);
}

const client = new sdk.Client().setEndpoint(ENDPOINT).setProject(PROJECT).setKey(API_KEY);
const databases = new sdk.Databases(client);
const users = new sdk.Users(client);

const categories = JSON.parse(fs.readFileSync(path.join(__dirname, 'categories.json'), 'utf8'));
const demo = JSON.parse(fs.readFileSync(path.join(__dirname, 'demo_accounts.json'), 'utf8'));

async function seedCategories() {
  console.log(`Seeding ${categories.length} service_categories...`);
  for (const cat of categories) {
    await databases.createDocument(DB_ID, 'service_categories', sdk.ID.unique(), cat).then(
      () => console.log(`  + ${cat.name}`),
      (e) => {
        if (e.code === 409) console.log(`  = ${cat.name} (already exists)`);
        else console.error(`  ! ${cat.name}: ${e.message}`);
      }
    );
  }
}

async function createDemoUser({ name, email, phone, role, language }) {
  // Auth user is created WITHOUT phone: this Appwrite project's phone-number validation
  // rejects +92 (Pakistan) numbers (a Console-level restriction, not something this script
  // controls). The display phone number below is a plain string field with no such check.
  const authUser = await users
    .create(sdk.ID.unique(), email, undefined, demo.password, name)
    .catch(async (e) => {
      if (e.code === 409) {
        const list = await users.list([sdk.Query.equal('email', email)]);
        return list.users[0];
      }
      throw e;
    });

  // userDoc.$id (NOT authUser.$id) is what customer_profiles/worker_profiles.userId must
  // reference — see plan §5.2/§5.3 "userId -> users.$id" and shared/ProfileRepository, which
  // both link via the `users` collection document id, not the Appwrite Auth user id.
  let userDoc = await databases.createDocument(DB_ID, 'users', sdk.ID.unique(), {
    authId: authUser.$id,
    role,
    name,
    phone: phone || '',
    email,
    language: language || 'en',
    status: 'active',
    riskScore: 0,
    createdVia: 'seed',
  }).catch(async (e) => {
    if (e.code === 409) {
      const list = await databases.listDocuments(DB_ID, 'users', [sdk.Query.equal('authId', authUser.$id), sdk.Query.limit(1)]);
      return list.documents[0];
    }
    throw e;
  });

  return { authUser, userDoc };
}

async function seedCustomers() {
  console.log(`Seeding ${demo.customers.length} customer(s)...`);
  for (const c of demo.customers) {
    const { userDoc } = await createDemoUser({ ...c, role: 'customer' });
    await databases.createDocument(DB_ID, 'customer_profiles', sdk.ID.unique(), {
      userId: userDoc.$id,
      currentLat: c.lat,
      currentLng: c.lng,
      totalBookings: 0,
      trustScore: 100,
    }).catch((e) => {
      if (e.code !== 409) console.error(`  customer_profiles for ${c.email}: ${e.message}`);
    });
    console.log(`  + ${c.name} (${c.email})`);
  }
}

async function seedWorkers() {
  console.log(`Seeding ${demo.workers.length} worker(s)...`);
  for (const w of demo.workers) {
    const { userDoc } = await createDemoUser({ ...w, role: 'worker' });
    await databases.createDocument(DB_ID, 'worker_profiles', sdk.ID.unique(), {
      userId: userDoc.$id,
      skills: w.skills,
      experienceYears: 3,
      serviceAreaLat: w.lat,
      serviceAreaLng: w.lng,
      serviceRadiusKm: 8,
      verificationStatus: 'approved',
      availability: 'online',
      rating: w.rating,
      jobsCompleted: w.jobsCompleted,
      walletBalance: 0,
      pendingBalance: 0,
      performanceScore: 80,
      currentLat: w.lat,
      currentLng: w.lng,
    }).catch((e) => {
      if (e.code !== 409) console.error(`  worker_profiles for ${w.email}: ${e.message}`);
    });
    console.log(`  + ${w.name} (${w.email})`);
  }
}

async function seedAdmin() {
  console.log('Seeding admin...');
  await createDemoUser({ ...demo.admin, phone: '', language: 'en', role: 'admin' });
  console.log(`  + ${demo.admin.name} (${demo.admin.email})`);
}

(async () => {
  await seedCategories();
  await seedCustomers();
  await seedWorkers();
  await seedAdmin();
  console.log('\nSeed complete. Demo password for all accounts:', demo.password);
})().catch((e) => {
  console.error('Seed failed:', e);
  process.exit(1);
});
