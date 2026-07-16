#!/usr/bin/env node
// functions/status.js — prints each function's latest deployment status + build logs tail.
// Usage: node functions/status.js [functionId ...]
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const sdk = require('node-appwrite');

const client = new sdk.Client()
  .setEndpoint(process.env.APPWRITE_ENDPOINT)
  .setProject(process.env.APPWRITE_PROJECT)
  .setKey(process.env.APPWRITE_API_KEY);
const functions = new sdk.Functions(client);

const config = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'appwrite.json'), 'utf8'));

(async () => {
  const only = process.argv.slice(2);
  const targets = only.length ? config.functions.filter((f) => only.includes(f.$id)) : config.functions;

  for (const fn of targets) {
    const deployments = await functions.listDeployments(fn.$id, [sdk.Query.orderDesc('$createdAt'), sdk.Query.limit(1)]);
    const d = deployments.deployments[0];
    if (!d) {
      console.log(`${fn.$id}: no deployments yet`);
      continue;
    }
    console.log(`${fn.$id}: deployment ${d.$id} status=${d.status} activate=${d.activate}`);
    if (d.status === 'failed' || only.length) {
      const logs = await functions.get(fn.$id).catch(() => null);
      console.log(`  buildLogs (truncated): ${(d.buildLogs || '').slice(-2000)}`);
    }
  }
})().catch((e) => {
  console.error('Status check failed:', e);
  process.exit(1);
});
