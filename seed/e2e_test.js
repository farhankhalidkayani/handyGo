#!/usr/bin/env node
// seed/e2e_test.js — one-off verification script (not part of the app) that drives the full
// Phase 2 booking lifecycle as REAL end-user sessions (via users.createSession, a server-side
// impersonation endpoint used here purely for testing), not the API key. This is the only way
// to verify client-side permission grants actually work, since the API key bypasses all
// permission checks. Usage: node seed/e2e_test.js
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const sdk = require('node-appwrite');

const ENDPOINT = process.env.APPWRITE_ENDPOINT;
const PROJECT = process.env.APPWRITE_PROJECT;
const API_KEY = process.env.APPWRITE_API_KEY;
const DB_ID = 'handygo';

const adminClient = new sdk.Client().setEndpoint(ENDPOINT).setProject(PROJECT).setKey(API_KEY);
const adminUsers = new sdk.Users(adminClient);
const adminDatabases = new sdk.Databases(adminClient);

function clientFor(session) {
  return new sdk.Client().setEndpoint(ENDPOINT).setProject(PROJECT).setSession(session.secret);
}

async function main() {
  console.log('--- Setting up real sessions for seeded customer + worker ---');
  const customerUserDoc = (await adminDatabases.listDocuments(DB_ID, 'users', [sdk.Query.equal('role', 'customer'), sdk.Query.limit(1)])).documents[0];
  const workerUserDoc = (await adminDatabases.listDocuments(DB_ID, 'users', [sdk.Query.equal('role', 'worker'), sdk.Query.limit(1)])).documents[0];
  console.log('customer:', customerUserDoc.name, customerUserDoc.$id);
  console.log('worker:', workerUserDoc.name, workerUserDoc.$id);

  const customerSession = await adminUsers.createSession(customerUserDoc.authId);
  const workerSession = await adminUsers.createSession(workerUserDoc.authId);

  const customerClient = clientFor(customerSession);
  const workerClient = clientFor(workerSession);
  const customerDb = new sdk.Databases(customerClient);
  const workerDb = new sdk.Databases(workerClient);
  const customerFunctions = new sdk.Functions(customerClient);
  const workerFunctions = new sdk.Functions(workerClient);

  async function callAiRouter(functions, feature, payload) {
    const exec = await functions.createExecution(
      'aiRouter',
      JSON.stringify({ feature, ...payload }),
      false,
      '/',
      'POST',
      { 'content-type': 'application/json' }
    );
    const body = exec.responseBody ? JSON.parse(exec.responseBody) : {};
    if (exec.responseStatusCode >= 400) throw new Error(`${feature} failed (${exec.responseStatusCode}): ${JSON.stringify(body)}`);
    return body;
  }

  console.log('\n--- 1. Customer creates a booking directly (client permission check) ---');
  const category = (await adminDatabases.listDocuments(DB_ID, 'service_categories', [sdk.Query.equal('name', 'Electrical'), sdk.Query.limit(1)])).documents[0];
  const booking = await customerDb.createDocument(DB_ID, 'bookings', sdk.ID.unique(), {
    customerId: customerUserDoc.$id,
    categoryId: category.$id,
    problemText: 'e2e test: socket sparking',
    addressText: 'e2e test address',
    lat: 31.52, lng: 74.35,
    status: 'draft',
    otp: '1234',
  }, []); // explicit empty permissions — mirrors shared/booking_repository.dart's fix
  console.log('OK booking created as customer client:', booking.$id);

  console.log('\n--- 1b. Customer CANNOT write booking.status directly (must be server-only) ---');
  try {
    await customerDb.updateDocument(DB_ID, 'bookings', booking.$id, { status: 'completed' });
    console.log('FAIL: client was able to update status directly — permission is too broad!');
  } catch (e) {
    console.log('OK correctly blocked:', e.message);
  }

  console.log('\n--- 2. transitionBooking: draft -> searching_workers (via aiRouter, as customer) ---');
  await callAiRouter(customerFunctions, 'transitionBooking', {
    bookingId: booking.$id, nextStatus: 'searching_workers', changedByRole: 'customer', changedById: customerUserDoc.$id,
  });
  console.log('OK');

  console.log('\n--- 3. Worker creates an offer directly (client permission check) ---');
  const offer = await workerDb.createDocument(DB_ID, 'worker_offers', sdk.ID.unique(), {
    bookingId: booking.$id, workerId: workerUserDoc.$id, quote: 1200, etaMins: 20, message: 'e2e test offer', status: 'sent',
  }, []); // explicit empty permissions — mirrors shared/offer_repository.dart's fix
  console.log('OK offer created as worker client:', offer.$id);

  console.log('\n--- 4. selectOffer (as customer) ---');
  await callAiRouter(customerFunctions, 'selectOffer', { bookingId: booking.$id, offerId: offer.$id, customerId: customerUserDoc.$id });
  const afterSelect = await adminDatabases.getDocument(DB_ID, 'bookings', booking.$id);
  console.log('OK booking.status =', afterSelect.status, ' workerId =', afterSelect.workerId, ' finalQuote =', afterSelect.finalQuote);

  console.log('\n--- 5. Drive the rest of the state machine (worker + customer + system) ---');
  const steps = [
    ['confirmed', 'worker', workerUserDoc.$id],
    ['worker_on_the_way', 'worker', workerUserDoc.$id],
    ['worker_arrived', 'worker', workerUserDoc.$id],
  ];
  for (const [nextStatus, role, id] of steps) {
    await callAiRouter(workerFunctions, 'transitionBooking', { bookingId: booking.$id, nextStatus, changedByRole: role, changedById: id });
    console.log('OK ->', nextStatus);
  }

  console.log('\n--- 5b. service_started with WRONG otp should fail ---');
  try {
    await callAiRouter(workerFunctions, 'transitionBooking', { bookingId: booking.$id, nextStatus: 'service_started', changedByRole: 'worker', changedById: workerUserDoc.$id, otp: '0000' });
    console.log('FAIL: wrong OTP was accepted!');
  } catch (e) {
    console.log('OK correctly rejected wrong OTP:', e.message);
  }

  console.log('\n--- 5c. service_started with correct otp ---');
  await callAiRouter(workerFunctions, 'transitionBooking', { bookingId: booking.$id, nextStatus: 'service_started', changedByRole: 'worker', changedById: workerUserDoc.$id, otp: '1234' });
  console.log('OK -> service_started');

  await callAiRouter(workerFunctions, 'transitionBooking', { bookingId: booking.$id, nextStatus: 'in_progress', changedByRole: 'system', changedById: workerUserDoc.$id });
  console.log('OK -> in_progress');
  await callAiRouter(workerFunctions, 'transitionBooking', { bookingId: booking.$id, nextStatus: 'completion_requested', changedByRole: 'worker', changedById: workerUserDoc.$id });
  console.log('OK -> completion_requested');
  await callAiRouter(customerFunctions, 'transitionBooking', { bookingId: booking.$id, nextStatus: 'payment_pending', changedByRole: 'customer', changedById: customerUserDoc.$id });
  console.log('OK -> payment_pending');
  await callAiRouter(customerFunctions, 'transitionBooking', { bookingId: booking.$id, nextStatus: 'completed', changedByRole: 'system', changedById: customerUserDoc.$id });
  console.log('OK -> completed');

  console.log('\n--- 6. Verify transaction auto-created on completion ---');
  const txns = await adminDatabases.listDocuments(DB_ID, 'transactions', [sdk.Query.equal('bookingId', booking.$id)]);
  console.log(txns.total ? `OK transaction created: total=${txns.documents[0].total} commission=${txns.documents[0].commission} netToWorker=${txns.documents[0].netToWorker}` : 'FAIL: no transaction found');

  console.log('\n--- 7. submitRating (as customer) ---');
  await callAiRouter(customerFunctions, 'submitRating', { bookingId: booking.$id, customerId: customerUserDoc.$id, rating: 5, reviewText: 'e2e test review' });
  const finalBooking = await adminDatabases.getDocument(DB_ID, 'bookings', booking.$id);
  console.log('OK booking.ratingGiven =', finalBooking.ratingGiven, ' reviewText =', finalBooking.reviewText);

  const workerProfile = (await adminDatabases.listDocuments(DB_ID, 'worker_profiles', [sdk.Query.equal('userId', workerUserDoc.$id), sdk.Query.limit(1)])).documents[0];
  console.log('OK worker_profiles.rating =', workerProfile.rating);

  console.log('\n--- Cleanup: deleting e2e test documents ---');
  await adminDatabases.deleteDocument(DB_ID, 'bookings', booking.$id);
  await adminDatabases.deleteDocument(DB_ID, 'worker_offers', offer.$id);
  if (txns.total) await adminDatabases.deleteDocument(DB_ID, 'transactions', txns.documents[0].$id);
  await adminUsers.deleteSession(customerUserDoc.authId, customerSession.$id);
  await adminUsers.deleteSession(workerUserDoc.authId, workerSession.$id);
  console.log('Cleaned up.\n\nALL E2E CHECKS PASSED.');
}

main().catch((e) => {
  console.error('\nE2E TEST FAILED:', e);
  process.exit(1);
});
