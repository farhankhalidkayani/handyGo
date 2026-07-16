#!/usr/bin/env node
// functions/deploy.js — idempotent Function deployment from ../appwrite.json using the
// node-appwrite SDK directly. Exists because `appwrite push functions` uses an arrow-key/
// checkbox interactive picker that can't be driven over piped/non-TTY input; this script
// creates/updates each function, tars its own directory (after `node functions/build.js`
// has synced lib/ into it), uploads a deployment, and activates it.
// Usage: node functions/deploy.js [functionId ...]   (no args = all functions)
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const sdk = require('node-appwrite');
const { InputFile } = require('node-appwrite/file');

const ENDPOINT = process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1';
const PROJECT = process.env.APPWRITE_PROJECT;
const API_KEY = process.env.APPWRITE_API_KEY;

if (!PROJECT || !API_KEY) {
  console.error('APPWRITE_PROJECT and APPWRITE_API_KEY must be set (see .env.example)');
  process.exit(1);
}

const client = new sdk.Client().setEndpoint(ENDPOINT).setProject(PROJECT).setKey(API_KEY);
const functions = new sdk.Functions(client);

const REPO_ROOT = path.join(__dirname, '..');
const config = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'appwrite.json'), 'utf8'));

// Env vars every function needs at runtime (mirrors .env.example, minus repo-only values).
const FUNCTION_ENV_KEYS = [
  'APPWRITE_ENDPOINT', 'APPWRITE_PROJECT', 'APPWRITE_API_KEY', 'APPWRITE_DB',
  'OLLAMA_URL', 'OLLAMA_MODEL', 'GROQ_API_KEY', 'GROQ_MODEL',
  'LIBRETRANSLATE_URL', 'OSRM_URL',
];

async function ensureFunction(fn) {
  const existing = await functions.get(fn.$id).catch((e) => (e.code === 404 ? null : Promise.reject(e)));
  if (!existing) {
    await functions.create(
      fn.$id, fn.name, fn.runtime, fn.execute, fn.events, fn.schedule, fn.timeout,
      true, true, fn.entrypoint
    );
    console.log(`  + created function ${fn.$id}`);
  } else {
    await functions.update(
      fn.$id, fn.name, fn.runtime, fn.execute, fn.events, fn.schedule, fn.timeout,
      true, true, fn.entrypoint
    );
    console.log(`  = updated function ${fn.$id}`);
  }
}

async function ensureVariables(fn) {
  const existing = await functions.listVariables(fn.$id);
  const existingKeys = new Set(existing.variables.map((v) => v.key));
  for (const key of FUNCTION_ENV_KEYS) {
    const value = process.env[key];
    if (value === undefined || value === '') continue;
    if (existingKeys.has(key)) continue; // updateVariable would need the variable id; skip if present
    await functions.createVariable(fn.$id, key, value);
    console.log(`    + var ${key}`);
  }
}

function tarFunctionDir(fnDir, outFile) {
  // tar the function dir's contents (src/, package.json) at the archive root, matching
  // what Appwrite expects to unpack alongside `entrypoint`.
  execFileSync('tar', ['-czf', outFile, '-C', fnDir, '.'], { stdio: 'inherit' });
}

async function deployFunction(fn) {
  console.log(`Function: ${fn.$id}`);
  await ensureFunction(fn);
  await ensureVariables(fn);

  const fnDir = path.join(REPO_ROOT, fn.path);
  const tarPath = path.join(REPO_ROOT, '.appwrite-deploy', `${fn.$id}.tar.gz`);
  fs.mkdirSync(path.dirname(tarPath), { recursive: true });
  tarFunctionDir(fnDir, tarPath);

  const deployment = await functions.createDeployment(
    fn.$id,
    InputFile.fromPath(tarPath, `${fn.$id}.tar.gz`),
    true, // activate immediately
    fn.entrypoint,
    'npm install'
  );
  console.log(`  + deployment ${deployment.$id} queued (activate=true)`);
  fs.rmSync(tarPath, { force: true });
}

(async () => {
  const only = process.argv.slice(2);
  const targets = only.length ? config.functions.filter((f) => only.includes(f.$id)) : config.functions;
  if (!targets.length) {
    console.error('No matching functions in appwrite.json for:', only.join(', '));
    process.exit(1);
  }
  for (const fn of targets) {
    await deployFunction(fn);
  }
  console.log('\nDeployment triggered for all targets. Builds run async on Appwrite Cloud —');
  console.log('check status with: node functions/status.js');
})().catch((e) => {
  console.error('Deploy failed:', e);
  process.exit(1);
});
