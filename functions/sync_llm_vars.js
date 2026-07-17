#!/usr/bin/env node
// functions/sync_llm_vars.js — one-off: deploy.js's ensureVariables only ever ADDS missing
// variables, never updates/removes existing ones. Switching from Ollama to Groq as tier-1
// needs OLLAMA_URL actually removed from both functions (lib/llm.js prefers Ollama whenever
// the env var is present at all, regardless of value) and GROQ_API_KEY set/updated.
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const sdk = require('node-appwrite');

const client = new sdk.Client()
  .setEndpoint(process.env.APPWRITE_ENDPOINT)
  .setProject(process.env.APPWRITE_PROJECT)
  .setKey(process.env.APPWRITE_API_KEY);
const functions = new sdk.Functions(client);

const FUNCTION_IDS = ['aiRouter', 'eventRouter'];

(async () => {
  for (const fnId of FUNCTION_IDS) {
    console.log(`Function: ${fnId}`);
    const existing = await functions.listVariables(fnId);

    const ollama = existing.variables.find((v) => v.key === 'OLLAMA_URL');
    if (ollama) {
      await functions.deleteVariable(fnId, ollama.$id);
      console.log('  - removed OLLAMA_URL');
    }

    const groq = existing.variables.find((v) => v.key === 'GROQ_API_KEY');
    if (groq) {
      await functions.updateVariable(fnId, groq.$id, 'GROQ_API_KEY', process.env.GROQ_API_KEY);
      console.log('  = updated GROQ_API_KEY');
    } else {
      await functions.createVariable(fnId, 'GROQ_API_KEY', process.env.GROQ_API_KEY);
      console.log('  + created GROQ_API_KEY');
    }

    const groqModel = existing.variables.find((v) => v.key === 'GROQ_MODEL');
    if (!groqModel) {
      await functions.createVariable(fnId, 'GROQ_MODEL', process.env.GROQ_MODEL);
      console.log('  + created GROQ_MODEL');
    }
  }
  console.log('\nDone. Redeploying so the running function picks up the new env...');
})().catch((e) => {
  console.error('Failed:', e);
  process.exit(1);
});
