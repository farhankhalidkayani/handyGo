// lib/aiRouter.js — tiered fallback LLM caller shared by every AI Appwrite Function.
// Tier 1: Ollama (or Groq if OLLAMA_URL unset and GROQ_API_KEY set) — tier 2/3 (rules, canned
// responses) live in each function itself, since only that function knows a sane fallback value.

const OLLAMA_URL = process.env.OLLAMA_URL || 'http://localhost:11434';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'qwen2.5:7b';
const GROQ_API_KEY = process.env.GROQ_API_KEY;
const GROQ_MODEL = process.env.GROQ_MODEL || 'llama-3.1-8b-instant';
// Vision-capable Groq model for photo-based problem intake (C4) — Groq's free tier includes
// this, so image classification stays inside the project's zero-cost design (§4 AI layer).
const GROQ_VISION_MODEL = process.env.GROQ_VISION_MODEL || 'meta-llama/llama-4-scout-17b-16e-instruct';
const TIMEOUT_MS = 20000;

async function askOllama(system, user, json) {
  const res = await fetch(`${OLLAMA_URL}/api/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: OLLAMA_MODEL,
      prompt: `${system}\n\nUser: ${user}\nAssistant:`,
      stream: false,
      format: json ? 'json' : undefined,
      options: { temperature: 0.3 },
    }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`Ollama HTTP ${res.status}`);
  const data = await res.json();
  return data.response;
}

async function askGroq(system, user, json) {
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${GROQ_API_KEY}`,
    },
    body: JSON.stringify({
      model: GROQ_MODEL,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
      temperature: 0.3,
      response_format: json ? { type: 'json_object' } : undefined,
    }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`Groq HTTP ${res.status}`);
  const data = await res.json();
  return data.choices?.[0]?.message?.content;
}

/**
 * Calls the tier-1 LLM. Returns { tier: 'llm', text } on success or
 * { tier: 'fallback', text: null, error } on any failure — callers MUST
 * handle the fallback case with a rules-based or canned response so a
 * dead model never blanks the UI (see §4.3 fallback ladder).
 */
async function askLLM(system, user, { json = false } = {}) {
  try {
    const text = GROQ_API_KEY && !process.env.OLLAMA_URL
      ? await askGroq(system, user, json)
      : await askOllama(system, user, json);
    return { tier: 'llm', text };
  } catch (e) {
    return { tier: 'fallback', text: null, error: e.message };
  }
}

/**
 * Vision variant of askLLM — Groq only (no local-Ollama vision fallback tier configured for
 * this project), so this simply returns the fallback shape if GROQ_API_KEY is unset or the
 * call fails. `imageDataUrl` must be a `data:image/...;base64,...` string — the caller fetches
 * the raw bytes server-side (bypassing Storage permissions via the API key) so this works
 * regardless of the file's own read permissions.
 */
async function askVisionLLM(system, imageDataUrl, { json = false } = {}) {
  if (!GROQ_API_KEY) return { tier: 'fallback', text: null, error: 'no GROQ_API_KEY configured' };
  try {
    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: GROQ_VISION_MODEL,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: system },
              { type: 'image_url', image_url: { url: imageDataUrl } },
            ],
          },
        ],
        temperature: 0.3,
        response_format: json ? { type: 'json_object' } : undefined,
      }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!res.ok) throw new Error(`Groq vision HTTP ${res.status}`);
    const data = await res.json();
    const text = data.choices?.[0]?.message?.content;
    return { tier: 'llm', text };
  } catch (e) {
    return { tier: 'fallback', text: null, error: e.message };
  }
}

function safeJsonParse(text, fallback = null) {
  if (!text) return fallback;
  try {
    return JSON.parse(text);
  } catch {
    const match = text.match(/\{[\s\S]*\}/);
    if (match) {
      try {
        return JSON.parse(match[0]);
      } catch {
        return fallback;
      }
    }
    return fallback;
  }
}

module.exports = { askLLM, askVisionLLM, safeJsonParse };
