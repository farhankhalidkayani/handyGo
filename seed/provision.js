#!/usr/bin/env node
// seed/provision.js — idempotent schema provisioning from ../appwrite.json using the
// node-appwrite SDK directly. Exists because `appwrite push collections` is an interactive
// CLI whose confirmation prompts don't work reliably over piped/non-TTY input; this script
// creates whatever's missing and skips (409) whatever already exists, safely re-runnable.
// Usage: node seed/provision.js
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const sdk = require('node-appwrite');

const ENDPOINT = process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1';
const PROJECT = process.env.APPWRITE_PROJECT;
const API_KEY = process.env.APPWRITE_API_KEY;

if (!PROJECT || !API_KEY) {
  console.error('APPWRITE_PROJECT and APPWRITE_API_KEY must be set (see .env.example)');
  process.exit(1);
}

const client = new sdk.Client().setEndpoint(ENDPOINT).setProject(PROJECT).setKey(API_KEY);
const databases = new sdk.Databases(client);

const config = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'appwrite.json'), 'utf8'));

function ignoreConflict(promise, label) {
  return promise.then(
    () => console.log(`  + ${label}`),
    (e) => {
      if (e.code === 409) console.log(`  = ${label} (already exists)`);
      else console.error(`  ! ${label}: ${e.message}`);
    }
  );
}

async function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function waitForAttribute(dbId, collectionId, key, attempts = 20) {
  for (let i = 0; i < attempts; i++) {
    const attr = await databases.getAttribute(dbId, collectionId, key).catch(() => null);
    if (attr && attr.status === 'available') return true;
    if (attr && attr.status === 'failed') return false;
    await sleep(1000);
  }
  return false;
}

async function createAttribute(dbId, collectionId, attr) {
  const label = `${collectionId}.${attr.key}`;
  let call;
  switch (attr.type) {
    case 'string':
      call = databases.createStringAttribute(dbId, collectionId, attr.key, attr.size, attr.required, attr.default, attr.array);
      break;
    case 'integer':
      call = databases.createIntegerAttribute(dbId, collectionId, attr.key, attr.required, attr.min, attr.max, attr.default, attr.array);
      break;
    case 'double':
      call = databases.createFloatAttribute(dbId, collectionId, attr.key, attr.required, attr.min, attr.max, attr.default, attr.array);
      break;
    case 'boolean':
      call = databases.createBooleanAttribute(dbId, collectionId, attr.key, attr.required, attr.default, attr.array);
      break;
    case 'datetime':
      call = databases.createDatetimeAttribute(dbId, collectionId, attr.key, attr.required, attr.default, attr.array);
      break;
    default:
      console.error(`  ! ${label}: unsupported type ${attr.type}`);
      return;
  }
  await ignoreConflict(call, label);
  await waitForAttribute(dbId, collectionId, attr.key);
}

async function createIndex(dbId, collectionId, index) {
  const label = `${collectionId} index ${index.key}`;
  await ignoreConflict(
    databases.createIndex(dbId, collectionId, index.key, index.type, index.attributes),
    label
  );
}

(async () => {
  for (const db of config.databases) {
    console.log(`Database: ${db.$id}`);
    await ignoreConflict(databases.create(db.$id, db.name, db.enabled), db.$id);
  }

  for (const col of config.collections) {
    console.log(`Collection: ${col.$id}`);
    await ignoreConflict(
      databases.createCollection(
        col.databaseId,
        col.$id,
        col.name,
        col.$permissions,
        col.documentSecurity,
        col.enabled
      ),
      col.$id
    );

    for (const attr of col.attributes) {
      await createAttribute(col.databaseId, col.$id, attr);
    }
    for (const index of col.indexes || []) {
      await createIndex(col.databaseId, col.$id, index);
    }
  }

  console.log('\nProvisioning complete.');
})().catch((e) => {
  console.error('Provisioning failed:', e);
  process.exit(1);
});
