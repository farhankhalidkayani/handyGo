#!/usr/bin/env node
// Copies functions/lib/* into each function's src/lib/ before deploy, since the Appwrite
// CLI only bundles a function's own "path" directory (see appwrite.json), not shared code.
// Run: node functions/build.js
const fs = require('fs');
const path = require('path');

const FUNCTIONS_DIR = __dirname;
const LIB_DIR = path.join(FUNCTIONS_DIR, 'lib');
const SKIP = new Set(['lib', 'node_modules', 'build.js']);

for (const name of fs.readdirSync(FUNCTIONS_DIR)) {
  if (SKIP.has(name)) continue;
  const fnDir = path.join(FUNCTIONS_DIR, name);
  if (!fs.statSync(fnDir).isDirectory()) continue;
  const destLib = path.join(fnDir, 'src', 'lib');
  fs.rmSync(destLib, { recursive: true, force: true });
  fs.cpSync(LIB_DIR, destLib, { recursive: true });
  console.log(`synced lib -> ${name}/src/lib`);
}
