// lib/appwriteClient.js — server-side Appwrite client shared by every Function.
// Uses the API key from env, never a client SDK key — see plan §11 (AI key isolation).
const sdk = require('node-appwrite');

const DB_ID = process.env.APPWRITE_DB || 'handygo';

function getClient() {
  return new sdk.Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1')
    .setProject(process.env.APPWRITE_PROJECT)
    .setKey(process.env.APPWRITE_API_KEY);
}

function getDatabases() {
  return new sdk.Databases(getClient());
}

function getStorage() {
  return new sdk.Storage(getClient());
}

module.exports = { sdk, getClient, getDatabases, getStorage, DB_ID };
