import { createServer } from 'node:http';
import { randomBytes, randomUUID, scryptSync, timingSafeEqual } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import * as db from './db.mjs';

// Initialize PostgreSQL connection
const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.error('ERROR: DATABASE_URL environment variable is required.');
  console.error('Example: DATABASE_URL=postgresql://iqroku:pass@localhost:5432/iqroku_db');
  process.exit(1);
}
db.initDb(DATABASE_URL);

// MiMo AI Configuration
const MIMO_API_URL = process.env.MIMO_API_URL || 'https://api.xiaomimimo.com/v1';
const MIMO_API_KEY = process.env.MIMO_API_KEY || '';
const MIMO_ASR_MODEL = process.env.MIMO_ASR_MODEL || 'mimo-v2.5-asr';
const MIMO_PRO_MODEL = process.env.MIMO_PRO_MODEL || 'mimo-v2.5-pro';

const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || 'https://iqroku.motionmind.store';

const port = Number(process.env.PORT ?? 8787);
const ADMIN_TOKEN = process.env.IQROKU_ADMIN_TOKEN || 'admin-dev-token';
if (ADMIN_TOKEN === 'admin-dev-token' && process.env.NODE_ENV === 'production') {
  console.error('FATAL: IQROKU_ADMIN_TOKEN must be set in production. Refusing to start with default token.');
  process.exit(1);
}
const MAX_BODY_SIZE = Number(process.env.MAX_BODY_SIZE) || 5 * 1024 * 1024; // 5MB max request body
const MAX_STRING_LENGTH = 500; // max string field length

// --- Rate Limiter ---
const rateLimits = new Map();
const RATE_WINDOW_MS = Number(process.env.RATE_WINDOW_MS) || 60_000; // 1 minute
const RATE_MAX_AUTH = Number(process.env.RATE_MAX_AUTH) || 10; // max auth attempts per IP per minute
const RATE_MAX_DEMO = 5; // max demo-login attempts per IP per minute
const RATE_MAX_GENERAL = Number(process.env.RATE_MAX_GENERAL) || 120; // max general requests per IP per minute

function getRateLimitKey(ip, bucket) {
  return `${ip}:${bucket}`;
}

function checkRateLimit(ip, bucket, max = RATE_MAX_GENERAL) {
  const key = getRateLimitKey(ip, bucket);
  const now = Date.now();
  let entry = rateLimits.get(key);
  if (!entry || now - entry.windowStart > RATE_WINDOW_MS) {
    entry = { windowStart: now, count: 0 };
    rateLimits.set(key, entry);
  }
  entry.count += 1;
  if (entry.count > max) {
    throw httpError(429, 'rate_limit_exceeded');
  }
}

// Cleanup stale rate limit entries every 5 minutes
setInterval(() => {
  const cutoff = Date.now() - RATE_WINDOW_MS * 2;
  for (const [key, entry] of rateLimits) {
    if (entry.windowStart < cutoff) {
      rateLimits.delete(key);
    }
  }
}, 300_000).unref();

// --- Session Store (PostgreSQL-backed) ---

async function storeSession(token, parentId) {
  await db.createSession(token, parentId);
}

async function resolveSessionToken(token) {
  return db.resolveSession(token);
}

async function revokeSession(token) {
  await db.deleteSession(token);
}

// --- Auth Middleware ---
async function authenticateRequest(request) {
  const authHeader = request.headers?.['authorization'] ?? '';
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice(7).trim()
    : '';

  if (!token) {
    throw httpError(401, 'missing_auth_token');
  }

  // Check session store (PostgreSQL)
  const parentId = await resolveSessionToken(token);
  if (parentId) {
    const parent = await db.findParentById(parentId);
    if (parent) {
      return parent;
    }
  }

  throw httpError(401, 'invalid_auth_token');
}

function authenticateAdmin(request) {
  const authHeader = request.headers?.['authorization'] ?? '';
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice(7).trim()
    : '';

  // Check cookie
  const cookie = request.headers?.['cookie'] ?? '';
  const cookieToken = cookie.match(/admin_token=([^;]+)/)?.[1] ?? '';

  if (token !== ADMIN_TOKEN && cookieToken !== ADMIN_TOKEN) {
    throw httpError(403, 'admin_access_denied');
  }
}

const server = createServer(async (request, response) => {
  const clientIp = request.socket?.remoteAddress ?? 'unknown';
  const startTime = Date.now();
  try {
    const url = new URL(request.url ?? '/', `http://${request.headers.host}`);
    const path = url.pathname;

    // Rate limit: stricter for auth endpoints
    const isAuthEndpoint = path.startsWith('/auth/');
    const isDemoLogin = path === '/auth/demo-login';
    const rateBucket = isDemoLogin ? 'demo' : isAuthEndpoint ? 'auth' : 'general';
    const rateMax = isDemoLogin ? RATE_MAX_DEMO : isAuthEndpoint ? RATE_MAX_AUTH : RATE_MAX_GENERAL;
    checkRateLimit(clientIp, rateBucket, rateMax);

    const body = await readJson(request);
    const result = await route(request.method ?? 'GET', url, body, request);
    const responseStatus = typeof result.status === 'number' ? result.status : 200;
    if (result.html) {
      sendHtml(response, responseStatus, result.html, result.headers);
      logRequest(request.method ?? 'GET', path, responseStatus, Date.now() - startTime, clientIp);
      return;
    }
    if (result.filePath) {
      await sendFile(response, result.filePath, result.contentType);
      logRequest(request.method ?? 'GET', path, 200, Date.now() - startTime, clientIp);
      return;
    }
    if (result.status === 302 && result.headers) {
      sendRedirect(response, result.status, result.headers);
      logRequest(request.method ?? 'GET', path, result.status, Date.now() - startTime, clientIp);
      return;
    }
    sendJson(response, responseStatus, result.body ?? result);
    logRequest(request.method ?? 'GET', path, responseStatus, Date.now() - startTime, clientIp);
  } catch (error) {
    const status = error.statusCode ?? 500;
    sendJson(response, status, {
      error: status === 500 ? 'internal_error' : error.message,
    });
    logRequest(request.method ?? 'GET', request.url ?? '/', status, Date.now() - startTime, clientIp);
    if (status === 500) {
      console.error(error);
    }
  }
});

server.listen(port, () => {
  console.log(`IqroKu backend listening on http://localhost:${port}`);
});

// --- Graceful Shutdown ---
function gracefulShutdown(signal) {
  console.log(`\n${signal} received. Shutting down gracefully...`);
  server.close(async () => {
    try {
      await db.closeDb();
    } catch (_) {
      // best-effort close
    }
    console.log('Server closed.');
    process.exit(0);
  });
  // Force exit after 5s if connections don't close
  setTimeout(() => process.exit(1), 5000).unref();
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

async function route(method, url, body, request) {
  const path = url.pathname;

  if (method === 'OPTIONS') {
    return {};
  }

  if (method === 'GET' && path === '/health') {
    try {
      const dbOk = await db.pingDb();
      return { ok: dbOk, service: 'iqroku-backend', store: 'postgresql', timestamp: new Date().toISOString() };
    } catch (_) {
      return { ok: false, service: 'iqroku-backend', store: 'postgresql', error: 'db_unreachable', timestamp: new Date().toISOString() };
    }
  }

  // --- Admin routes (require admin token) ---
  if (method === 'GET' && path === '/admin/login') {
    return { html: renderAdminLogin() };
  }

  if (method === 'POST' && path === '/admin/login') {
    const token = cleanString(body.token);
    if (token !== ADMIN_TOKEN) {
      return { html: renderAdminLogin('Token salah. Silakan coba lagi.') };
    }
    return {
      status: 302,
      headers: {
        'Set-Cookie': `admin_token=${token}; Path=/admin; HttpOnly; SameSite=Strict; Max-Age=86400`,
        'Location': '/admin',
      },
      body: '',
    };
  }

  if (method === 'GET' && path === '/admin/logout') {
    return {
      status: 302,
      headers: {
        'Set-Cookie': 'admin_token=; Path=/admin; HttpOnly; Max-Age=0',
        'Location': '/admin/login',
      },
      body: '',
    };
  }

  if (method === 'GET' && path === '/admin') {
    authenticateAdmin(request);
    const metrics = await db.getAdminMetrics();
    return { html: renderAdminDashboard(metrics) };
  }

  if (method === 'GET' && path === '/admin/metrics') {
    authenticateAdmin(request);
    return db.getAdminMetrics();
  }

  if (method === 'GET' && path === '/admin/prayers') {
    authenticateAdmin(request);
    const prayers = await db.getAllPrayers();
    return { html: renderAdminPrayers(prayers) };
  }

  if (method === 'GET' && path === '/daily-prayers') {
    const prayers = await db.getActivePrayers();
    return prayers.map(publicPrayer);
  }

  if (method === 'GET' && path.startsWith('/uploads/audio/')) {
    const fileName = safeStoredFileName(path.split('/').pop() ?? '');
    return {
      filePath: resolve('uploads/audio', fileName),
      contentType: contentTypeForAudio(fileName),
    };
  }

  if (method === 'POST' && path === '/admin/prayers') {
    authenticateAdmin(request);
    const fields = prayerFromBody(body);
    await db.createPrayer({
      id: randomUUID(),
      ...fields,
      active: parseBoolean(body.active, true),
    });
    const prayers = await db.getAllPrayers();
    return { html: renderAdminPrayers(prayers, 'Doa baru sudah tersimpan.') };
  }

  const prayerAction = adminPrayerAction(path);
  if (method === 'POST' && prayerAction) {
    authenticateAdmin(request);
    const prayer = await db.findPrayerById(prayerAction.id);
    if (!prayer) {
      throw httpError(404, 'prayer_not_found');
    }
    if (prayerAction.action === 'delete') {
      await db.deletePrayer(prayerAction.id);
      const prayers = await db.getAllPrayers();
      return { html: renderAdminPrayers(prayers, 'Doa sudah dihapus.') };
    }
    await db.updatePrayer(prayerAction.id, {
      ...prayerFromBody(body),
      active: parseBoolean(body.active, false),
    });
    const prayers = await db.getAllPrayers();
    return { html: renderAdminPrayers(prayers, 'Perubahan doa sudah tersimpan.') };
  }

  if (method === 'POST' && path === '/auth/demo-login') {
    const email = cleanString(body.email) || 'parent@iqroku.local';
    const name = cleanString(body.name) || 'Orang Tua';
    let parent = await db.findParentByEmail(email);
    if (!parent) {
      parent = await db.createParent({ id: randomUUID(), email, name });
    }
    const token = `demo_${parent.id}`;
    await storeSession(token, parent.id);
    return { parent: publicParent(parent), session: { token, type: 'demo' } };
  }

  if (method === 'POST' && path === '/auth/register') {
    const name = truncateString(cleanString(requiredBody(body, 'name')));
    const email = normalizeEmail(requiredBody(body, 'email'));
    const password = cleanString(requiredBody(body, 'password'));
    validatePassword(password);

    const existing = await db.findParentByEmail(email);
    if (existing) {
      throw httpError(409, 'email_already_registered');
    }

    const parent = await db.createParent({
      id: randomUUID(),
      email,
      name,
      passwordHash: hashPassword(password),
    });
    const token = createSessionToken(parent.id);
    await storeSession(token, parent.id);
    return {
      status: 201,
      body: {
        parent: publicParent(parent),
        session: { token, type: 'password' },
      },
    };
  }

  if (method === 'POST' && path === '/auth/login') {
    const email = normalizeEmail(requiredBody(body, 'email'));
    const password = cleanString(requiredBody(body, 'password'));
    const parent = await db.findParentByEmail(email);
    if (!parent || !parent.passwordHash || !verifyPassword(password, parent.passwordHash)) {
      throw httpError(401, 'invalid_email_or_password');
    }

    const token = createSessionToken(parent.id);
    await storeSession(token, parent.id);
    return {
      parent: publicParent(parent),
      session: { token, type: 'password' },
    };
  }

  if (method === 'POST' && path === '/auth/google') {
    const idToken = cleanString(requiredBody(body, 'idToken'));
    const email = normalizeEmail(requiredBody(body, 'email'));
    const name = truncateString(cleanString(body.name) || 'User');
    const googleId = cleanString(body.googleId);

    if (!googleId) {
      throw httpError(400, 'missing_google_id');
    }

    // Try to find existing user by email
    let parent = await db.findParentByEmail(email);

    if (parent) {
      // Update Google ID if not set
      if (!parent.googleId) {
        await db.updateParent(parent.id, { googleId });
      }
    } else {
      // Create new user
      parent = await db.createParent({
        id: randomUUID(),
        email,
        name,
        googleId,
      });
    }

    const token = createSessionToken(parent.id);
    await storeSession(token, parent.id);
    return {
      parent: publicParent(parent),
      session: { token, type: 'google' },
    };
  }

  // --- Protected routes (require user auth) ---
  if (method === 'GET' && path === '/children') {
    const authedParent = await authenticateRequest(request);
    const parentId = requiredQuery(url, 'parentId');
    if (parentId !== authedParent.id) {
      throw httpError(403, 'access_denied');
    }
    return db.findChildrenByParent(parentId);
  }

  if (method === 'POST' && path === '/children') {
    const authedParent = await authenticateRequest(request);
    const parentId = requiredBody(body, 'parentId');
    if (parentId !== authedParent.id) {
      throw httpError(403, 'access_denied');
    }
    await enforceChildLimit(authedParent.id);
    const child = await db.createChild({
      id: randomUUID(),
      parentId,
      name: truncateString(cleanString(body.name) || 'Anak'),
      age: clampNumber(Number(body.age ?? 7), 1, 18),
      avatarAsset: cleanString(body.avatarAsset) || 'assets/brand/male-avatar.png',
    });
    return { status: 201, body: child };
  }

  if (method === 'GET' && path === '/progress') {
    const authedParent = await authenticateRequest(request);
    const childId = requiredQuery(url, 'childId');
    await enforceChildOwnership(authedParent.id, childId);
    return db.findProgressByChild(childId);
  }

  if (method === 'PUT' && path === '/progress') {
    const authedParent = await authenticateRequest(request);
    const childId = requiredBody(body, 'childId');
    await enforceChildOwnership(authedParent.id, childId);
    const bookId = clampNumber(Number(requiredBody(body, 'bookId')), 1, 99);
    const pageNumber = clampNumber(Number(requiredBody(body, 'pageNumber')), 1, 999);
    const status = cleanString(requiredBody(body, 'status'));
    const VALID_STATUSES = ['notStarted', 'learning', 'fluent', 'review'];
    if (!VALID_STATUSES.includes(status)) {
      throw httpError(400, 'invalid_status');
    }
    return db.upsertProgress({ childId, bookId, pageNumber, status });
  }

  if (method === 'GET' && path === '/attempts') {
    const authedParent = await authenticateRequest(request);
    const childId = requiredQuery(url, 'childId');
    await enforceChildOwnership(authedParent.id, childId);
    return db.findAttemptsByChild(childId);
  }

  if (method === 'POST' && path === '/attempts') {
    const authedParent = await authenticateRequest(request);
    const childId = requiredBody(body, 'childId');
    await enforceChildOwnership(authedParent.id, childId);
    const attemptId = cleanString(body.id) || randomUUID();
    const attempt = await db.createAttempt({
      id: attemptId,
      childId,
      bookId: clampNumber(Number(requiredBody(body, 'bookId')), 1, 99),
      pageNumber: clampNumber(Number(requiredBody(body, 'pageNumber')), 1, 999),
      durationSeconds: clampNumber(Number(body.durationSeconds ?? 1), 1, 3600),
      audioPath: cleanString(body.audioPath) || null,
    });
    return { status: 201, body: attempt };
  }

  const audioUpload = attemptAudioUpload(path);
  if (method === 'POST' && audioUpload) {
    const authedParent = await authenticateRequest(request);
    const attempt = await db.findAttemptById(audioUpload.attemptId);
    if (!attempt) {
      throw httpError(404, 'attempt_not_found');
    }
    await enforceChildOwnership(authedParent.id, attempt.childId);
    const audio = body.__multipart?.files?.audio;
    if (!audio?.content?.length) {
      throw httpError(400, 'missing_audio');
    }
    const stored = await storeAttemptAudio({
      attemptId: attempt.id,
      originalFileName: audio.fileName,
      contentType: audio.contentType,
      content: audio.content,
    });
    return db.updateAttempt(attempt.id, {
      audioPath: stored.url,
      audioUrl: stored.url,
      audioFileName: stored.fileName,
      audioContentType: stored.contentType,
      audioSizeBytes: stored.sizeBytes,
      audioUploadedAt: now(),
    });
  }

  if (method === 'POST' && path === '/assessments/mock') {
    const authedParent = await authenticateRequest(request);
    const attemptId = requiredBody(body, 'attemptId');
    const attempt = await db.findAttemptById(attemptId);
    if (!attempt) {
      throw httpError(404, 'attempt_not_found');
    }
    await enforceChildOwnership(authedParent.id, attempt.childId);
    const result = scoreAttempt({
      pageNumber: attempt.pageNumber,
      durationSeconds: attempt.durationSeconds,
      targetLines: Array.isArray(body.targetLines) ? body.targetLines : [],
    });
    return db.updateAttempt(attempt.id, {
      score: result.score,
      status: result.status,
      feedback: result.feedback,
      note: result.note,
      assessmentStatus: result.status === 'fluent' ? 'fluent' : 'needsReview',
      assessedAt: now(),
    });
  }

  if (method === 'POST' && path === '/assessments/ai') {
    console.log('[API] AI Assessment requested');
    const authedParent = await authenticateRequest(request);
    const attemptId = requiredBody(body, 'attemptId');
    console.log('[API] Attempt ID:', attemptId);

    const attempt = await db.findAttemptById(attemptId);
    if (!attempt) {
      console.log('[API] Attempt not found:', attemptId);
      throw httpError(404, 'attempt_not_found');
    }
    await enforceChildOwnership(authedParent.id, attempt.childId);

    // Get audio file
    const audioPath = attempt.audioPath;
    console.log('[API] Audio path from DB:', audioPath);

    if (!audioPath) {
      console.log('[API] No audio recorded for attempt:', attemptId);
      throw httpError(400, 'no_audio_recorded');
    }

    // Read audio file
    const audioFileName = audioPath.split('/').pop();
    const audioFullPath = resolve('uploads/audio', audioFileName);
    console.log('[API] Looking for audio at:', audioFullPath);

    let audioBuffer;
    try {
      audioBuffer = await readFile(audioFullPath);
      console.log('[API] Audio file read successfully, size:', audioBuffer.length);
    } catch (err) {
      console.log('[API] Audio file not found:', audioFullPath, err.message);
      throw httpError(404, 'audio_file_not_found');
    }

    // Get target lines
    const targetLines = Array.isArray(body.targetLines) ? body.targetLines : [];

    // Call MiMo AI for assessment
    const result = await assessWithMiMo({
      audioBuffer,
      targetLines,
      pageNumber: attempt.pageNumber,
      bookId: attempt.bookId,
    });

    return db.updateAttempt(attempt.id, {
      score: result.score,
      status: result.status,
      feedback: result.feedback,
      note: result.note,
      assessmentStatus: result.status === 'fluent' ? 'fluent' : 'needsReview',
      assessedAt: now(),
    });
  }

  if (method === 'POST' && path === '/subscriptions/activate') {
    authenticateAdmin(request);
    const parentId = requiredBody(body, 'parentId');
    const parent = await db.findParentById(parentId);
    if (!parent) {
      throw httpError(404, 'parent_not_found');
    }
    const activeUntil = addDays(new Date(), 30).toISOString();
    return db.upsertSubscription({
      id: randomUUID(),
      parentId,
      plan: 'plus',
      priceId: 'iqroku_plus_49000_monthly',
      active: true,
      activatedAt: now(),
      activeUntil,
    });
  }

  throw httpError(404, 'not_found');
}

async function readJson(request) {
  if (!['POST', 'PUT', 'PATCH'].includes(request.method ?? 'GET')) {
    return {};
  }

  const chunks = [];
  let totalSize = 0;
  for await (const chunk of request) {
    totalSize += chunk.length;
    if (totalSize > MAX_BODY_SIZE) {
      throw httpError(413, 'request_body_too_large');
    }
    chunks.push(chunk);
  }
  const buffer = Buffer.concat(chunks);
  const contentType = String(request.headers['content-type'] ?? '');
  const boundary = multipartBoundary(contentType);
  if (boundary) {
    return { __multipart: parseMultipart(buffer, boundary) };
  }
  const raw = buffer.toString('utf8').trim();
  if (!raw) {
    return {};
  }
  if (contentType.includes('application/x-www-form-urlencoded')) {
    return Object.fromEntries(new URLSearchParams(raw));
  }
  try {
    return JSON.parse(raw);
  } catch (_) {
    throw httpError(400, 'invalid_json');
  }
}

function sendJson(response, status, body) {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': ALLOWED_ORIGIN,
    'access-control-allow-methods': 'GET,POST,PUT,OPTIONS',
    'access-control-allow-headers': 'content-type,authorization',
  });
  response.end(JSON.stringify(body));
}

function sendHtml(response, status, html, extraHeaders = {}) {
  response.writeHead(status, {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
    'content-security-policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self';",
    'x-frame-options': 'DENY',
    'x-content-type-options': 'nosniff',
    ...extraHeaders,
  });
  response.end(html);
}

function sendRedirect(response, status, headers) {
  response.writeHead(status, headers);
  response.end();
}

async function sendFile(response, filePath, contentType = 'application/octet-stream') {
  try {
    const content = await readFile(filePath);
    response.writeHead(200, {
      'content-type': contentType,
      'cache-control': 'public, max-age=3600',
      'access-control-allow-origin': ALLOWED_ORIGIN,
    });
    response.end(content);
  } catch (error) {
    if (error.code === 'ENOENT') {
      sendJson(response, 404, { error: 'file_not_found' });
      return;
    }
    throw error;
  }
}

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function truncateString(value) {
  const str = cleanString(value);
  return str.length > MAX_STRING_LENGTH ? str.slice(0, MAX_STRING_LENGTH) : str;
}

function clampNumber(value, min, max) {
  const num = Number.isFinite(value) ? value : min;
  return Math.max(min, Math.min(max, num));
}

async function enforceChildOwnership(parentId, childId) {
  const child = await db.findChildById(childId);
  if (!child || child.parentId !== parentId) {
    throw httpError(403, 'access_denied');
  }
}

function normalizeEmail(value) {
  const email = cleanString(value).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw httpError(400, 'invalid_email');
  }
  if (email.length > 254) {
    throw httpError(400, 'invalid_email');
  }
  return email;
}

function validatePassword(password) {
  if (password.length < 6) {
    throw httpError(400, 'password_min_6');
  }
  if (password.length > 128) {
    throw httpError(400, 'password_too_long');
  }
}

function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  const hash = scryptSync(password, salt, 64).toString('hex');
  return `scrypt:${salt}:${hash}`;
}

function verifyPassword(password, encoded) {
  const [scheme, salt, expectedHex] = String(encoded).split(':');
  if (scheme !== 'scrypt' || !salt || !expectedHex) {
    return false;
  }
  const expected = Buffer.from(expectedHex, 'hex');
  const actual = scryptSync(password, salt, expected.length);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

function createSessionToken(parentId) {
  return `session_${parentId}_${randomBytes(24).toString('hex')}`;
}

function publicParent(parent) {
  const { passwordHash, ...safeParent } = parent;
  return safeParent;
}

function requiredBody(body, key) {
  const value = body[key];
  if (value === undefined || value === null || value === '') {
    throw httpError(400, `missing_${key}`);
  }
  return value;
}

function requiredQuery(url, key) {
  const value = url.searchParams.get(key);
  if (!value) {
    throw httpError(400, `missing_${key}`);
  }
  return value;
}

async function enforceChildLimit(parentId) {
  const subscription = await db.findSubscriptionByParent(parentId);
  const limit = subscription?.active ? 5 : 1;
  const count = await db.countChildrenByParent(parentId);
  if (count >= limit) {
    throw httpError(402, 'child_limit_requires_plus');
  }
}

function scoreAttempt({ pageNumber, durationSeconds, targetLines }) {
  // More realistic mock scoring with randomness
  const baseScore = 50;
  const durationScore = Math.min(Math.max(durationSeconds, 1), 30) * 0.5;
  const pageScore = (pageNumber % 3) * 2;
  const materialBonus = targetLines.length > 0 ? 5 : 0;
  const randomVariation = Math.floor(Math.random() * 11) - 5; // -5 to +5

  const score = Math.round(Math.min(Math.max(baseScore + durationScore + pageScore + materialBonus + randomVariation, 40), 95));
  const passed = score >= 75;

  return {
    score,
    status: passed ? 'fluent' : 'review',
    feedback: passed
      ? 'Bacaan sudah cukup lancar. Pertahankan tempo dan lanjutkan dengan percaya diri.'
      : 'Sudah bagus berani membaca. Ulangi pelan-pelan bagian yang masih tersendat.',
    note: passed
      ? 'Hasil penilaian: lancar dengan toleransi latihan anak.'
      : 'Hasil penilaian: perlu ulang agar bacaan makin mantap.',
  };
}

async function assessWithMiMo({ audioBuffer, targetLines, pageNumber, bookId }) {
  if (!MIMO_API_KEY) {
    console.warn('[AI] MIMO_API_KEY not set, falling back to mock scoring');
    return scoreAttempt({ pageNumber, durationSeconds: 10, targetLines });
  }

  try {
    console.log('[AI] Starting assessment...');
    console.log('[AI] Audio size:', audioBuffer.length, 'bytes');
    console.log('[AI] Target lines:', targetLines.length);

    // Step 1: Transcribe audio using MiMo ASR
    console.log('[AI] Transcribing audio with MiMo ASR...');
    const transcribedText = await transcribeWithMiMoASR(audioBuffer);
    console.log('[AI] Transcribed text:', transcribedText.substring(0, 100) + '...');

    // Step 2: Compare and generate feedback using MiMo Pro
    const targetText = targetLines.map(line => line.join(' ')).join('\n');
    console.log('[AI] Generating feedback with MiMo Pro...');
    const feedback = await generateFeedbackWithMiMo(transcribedText, targetText, pageNumber, bookId);

    // Calculate score based on comparison
    const similarity = calculateSimilarity(transcribedText, targetText);
    const score = Math.round(60 + (similarity * 36)); // Scale 0-1 to 60-96
    const passed = score >= 80;

    console.log('[AI] Similarity:', similarity, 'Score:', score, 'Passed:', passed);

    return {
      score,
      status: passed ? 'fluent' : 'review',
      feedback: feedback.feedback,
      note: feedback.note,
    };
  } catch (error) {
    console.error('[AI] MiMo AI assessment failed:', error.message);
    console.error('[AI] Falling back to mock scoring');
    return scoreAttempt({ pageNumber, durationSeconds: 10, targetLines });
  }
}

async function transcribeWithMiMoASR(audioBuffer) {
  const base64Audio = audioBuffer.toString('base64');
  const dataUrl = `data:audio/m4a;base64,${base64Audio}`;

  const response = await fetch(`${MIMO_API_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${MIMO_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: MIMO_ASR_MODEL,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'input_audio',
              input_audio: {
                data: dataUrl,
                format: 'm4a',
              },
            },
            {
              type: 'text',
              text: 'Transkripsikan audio ini ke teks Arab. Hanya tulis teks Arab yang terdengar, tanpa penjelasan.',
            },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`MiMo ASR failed: ${response.status} - ${error}`);
  }

  const data = await response.json();
  return data.choices?.[0]?.message?.content || '';
}

async function generateFeedbackWithMiMo(transcribed, target, pageNumber, bookId) {
  const response = await fetch(`${MIMO_API_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${MIMO_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: MIMO_PRO_MODEL,
      messages: [
        {
          role: 'system',
          content: `Kamu adalah guru ngaji yang sabar dan mendukung untuk anak-anak. Tugasmu adalah menilai bacaan Iqro dengan detail dan memberikan umpan balik yang membangun.

TUGASAN: Iqro ${bookId}, Halaman ${pageNumber}

FORMAT RESPONSE (JSON):
{
  "score": <angka 0-100>,
  "correct_parts": "<bagian yang benar, misal: 'Alif (✓), Ba (✓)'",
  "wrong_parts": "<bagian yang salah dengan koreksi, misal: 'ب dibaca ت - seharusnya Ba bukan Ta'",
  "feedback": "<umpan balik untuk anak: 2-3 kalimat, positif, sebutkan huruf Arab dan Latinnya>",
  "note": "<catatan untuk orang tua: detail teknis kesalahan dan saran perbaikan>"
}

ATURAN PENILAIAN:
- Perhatikan setiap huruf yang dibaca anak
- Bandingkan dengan teks target huruf per huruf
- Jika ada huruf yang salah sebut, sebutkan huruf yang benar
- Berikan pujian untuk bagian yang benar
- Koreksi bagian yang salah dengan cara yang lembut
- Skor: 90-100 = Sangat Lancar, 70-89 = Lancar, 40-69 = Perlu Belajar, 0-39 = Perlu Ulang
- Gunakan nama Latin huruf (Alif, Ba, Ta, dll) agar anak mudah paham

CONTOH RESPONSE:
{
  "score": 65,
  "correct_parts": "Alif (✓) dan Lam (✓) sudah benar",
  "wrong_parts": "ب (Ba) salah dibaca ت (Ta) - coba rapatkan bibir",
  "feedback": "Alhamdulillah, Alif dan Lam sudah benar! Untuk ب (Ba), coba rapatkan bibir atas dan bawah ya. Ulangi lagi!",
  "note": "Anak masih tertukar ب dan ت. Perlu latihan pembedaan huruf yang mirip. Fokus pada posisi bibir untuk Ba."
}`,
        },
        {
          role: 'user',
          content: `Teks target (yang seharusnya dibaca):\n${target}\n\nHasil rekaman anak:\n${transcribed}\n\nBandingkan huruf per huruf. Berikan penilaian detail.`,
        },
      ],
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`MiMo Pro failed: ${response.status} - ${error}`);
  }

  const data = await response.json();
  const content = data.choices?.[0]?.message?.content || '';

  try {
    // Try to parse JSON response
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }
  } catch (_) {
    // Fallback if JSON parsing fails
  }

  return {
    feedback: 'Bacaan sudah bagus. Terus berlatih ya!',
    note: 'Perlu evaluasi lebih lanjut.',
  };
}

function calculateSimilarity(text1, text2) {
  if (!text1 || !text2) return 0;

  // Normalize Arabic text
  const normalize = (t) => t.replace(/[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]/g, '').trim();
  const a = normalize(text1);
  const b = normalize(text2);

  if (a === b) return 1;
  if (!a || !b) return 0;

  // Simple character-based similarity
  let matches = 0;
  const maxLen = Math.max(a.length, b.length);
  const minLen = Math.min(a.length, b.length);

  for (let i = 0; i < minLen; i++) {
    if (a[i] === b[i]) matches++;
  }

  return matches / maxLen;
}

function publicPrayer(prayer) {
  return {
    id: prayer.id,
    title: prayer.title,
    category: prayer.category,
    arabic: prayer.arabic,
    latin: prayer.latin,
    meaning: prayer.meaning,
    sortOrder: Number(prayer.sortOrder ?? 0),
  };
}

function prayerFromBody(body) {
  const title = cleanString(requiredBody(body, 'title'));
  const arabic = cleanString(requiredBody(body, 'arabic'));
  const meaning = cleanString(requiredBody(body, 'meaning'));
  return {
    title,
    category: cleanString(body.category) || 'Harian',
    arabic,
    latin: cleanString(body.latin),
    meaning,
    sortOrder: Number(body.sortOrder ?? 100),
  };
}

function adminPrayerAction(path) {
  const match = /^\/admin\/prayers\/([^/]+)\/(update|delete)$/.exec(path);
  if (!match) {
    return null;
  }
  return { id: decodeURIComponent(match[1]), action: match[2] };
}

function attemptAudioUpload(path) {
  const match = /^\/attempts\/([^/]+)\/audio$/.exec(path);
  if (!match) {
    return null;
  }
  return { attemptId: decodeURIComponent(match[1]) };
}

function multipartBoundary(contentType) {
  const match = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(contentType);
  return match?.[1] ?? match?.[2] ?? '';
}

function parseMultipart(buffer, boundary) {
  const payload = buffer.toString('latin1');
  const parts = payload.split(`--${boundary}`);
  const result = { fields: {}, files: {} };

  for (let part of parts) {
    if (!part || part === '--\r\n' || part === '--') {
      continue;
    }
    if (part.startsWith('\r\n')) {
      part = part.slice(2);
    }
    if (part.endsWith('\r\n')) {
      part = part.slice(0, -2);
    }
    if (part.endsWith('--')) {
      part = part.slice(0, -2);
    }

    const headerEnd = part.indexOf('\r\n\r\n');
    if (headerEnd === -1) {
      continue;
    }
    const headersRaw = part.slice(0, headerEnd);
    let contentRaw = part.slice(headerEnd + 4);
    if (contentRaw.endsWith('\r\n')) {
      contentRaw = contentRaw.slice(0, -2);
    }

    const headers = parsePartHeaders(headersRaw);
    const disposition = headers['content-disposition'] ?? '';
    const name = dispositionValue(disposition, 'name');
    if (!name) {
      continue;
    }
    const fileName = dispositionValue(disposition, 'filename');
    const content = Buffer.from(contentRaw, 'latin1');
    if (fileName) {
      result.files[name] = {
        fileName,
        content,
        contentType: headers['content-type'] ?? 'application/octet-stream',
      };
    } else {
      result.fields[name] = content.toString('utf8');
    }
  }

  return result;
}

function parsePartHeaders(headersRaw) {
  return Object.fromEntries(
    headersRaw.split('\r\n').map((line) => {
      const separator = line.indexOf(':');
      if (separator === -1) {
        return ['', ''];
      }
      return [
        line.slice(0, separator).trim().toLowerCase(),
        line.slice(separator + 1).trim(),
      ];
    }).filter(([key]) => key),
  );
}

function dispositionValue(disposition, key) {
  const match = new RegExp(`${key}="([^"]*)"`).exec(disposition);
  return match?.[1] ?? '';
}

async function storeAttemptAudio({ attemptId, originalFileName, contentType, content }) {
  const directory = resolve('uploads/audio');
  await mkdir(directory, { recursive: true });
  const extension = audioExtension(originalFileName, contentType);
  const fileName = safeStoredFileName(`${attemptId}-${Date.now()}${extension}`);
  await writeFile(resolve(directory, fileName), content);
  return {
    fileName,
    contentType: contentType || contentTypeForAudio(fileName),
    sizeBytes: content.length,
    url: `/uploads/audio/${fileName}`,
  };
}

function audioExtension(fileName = '', contentType = '') {
  const extension = extname(fileName).toLowerCase();
  if (['.m4a', '.mp3', '.aac', '.wav', '.webm', '.mp4'].includes(extension)) {
    return extension;
  }
  if (contentType.includes('mpeg')) {
    return '.mp3';
  }
  if (contentType.includes('wav')) {
    return '.wav';
  }
  if (contentType.includes('webm')) {
    return '.webm';
  }
  return '.m4a';
}

function safeStoredFileName(fileName) {
  return String(fileName).replaceAll(/[^a-zA-Z0-9._-]/g, '_');
}

function contentTypeForAudio(fileName) {
  const extension = extname(fileName).toLowerCase();
  return {
    '.aac': 'audio/aac',
    '.m4a': 'audio/mp4',
    '.mp3': 'audio/mpeg',
    '.mp4': 'audio/mp4',
    '.wav': 'audio/wav',
    '.webm': 'audio/webm',
  }[extension] ?? 'application/octet-stream';
}

function parseBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }
  return ['true', '1', 'yes', 'on'].includes(String(value).toLowerCase());
}

function renderAdminLogin(error = '') {
  return `<!doctype html>
<html lang="id">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Login - IqroKu Admin</title>
    <style>
      :root {
        color-scheme: light;
        --canvas: #f8f6ef;
        --surface: #ffffff;
        --line: #e7e1d6;
        --text: #17201b;
        --muted: #6d756f;
        --primary: #23864b;
        --primary-dark: #0f5b39;
        --danger: #d84f3f;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        color: var(--text);
        background: linear-gradient(180deg, var(--canvas), #fff);
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .login-card {
        background: var(--surface);
        border: 1px solid var(--line);
        border-radius: 20px;
        box-shadow: 0 8px 24px rgba(0, 0, 0, .08);
        padding: 40px;
        width: min(420px, calc(100% - 32px));
      }
      h1 { margin: 0 0 8px; font-size: 24px; }
      p { margin: 0 0 24px; color: var(--muted); font-size: 14px; }
      label {
        display: grid;
        gap: 8px;
        color: var(--muted);
        font-size: 13px;
        font-weight: 700;
        margin-bottom: 20px;
      }
      input {
        width: 100%;
        border: 1px solid var(--line);
        border-radius: 12px;
        padding: 14px 16px;
        color: var(--text);
        background: #fff;
        font: inherit;
        font-size: 15px;
      }
      input:focus {
        outline: none;
        border-color: var(--primary);
        box-shadow: 0 0 0 3px rgba(35, 134, 75, .15);
      }
      button {
        width: 100%;
        border: 0;
        border-radius: 12px;
        padding: 14px;
        background: var(--primary);
        color: #fff;
        font-weight: 800;
        font-size: 15px;
        cursor: pointer;
        transition: background .2s;
      }
      button:hover { background: var(--primary-dark); }
      .error {
        padding: 12px 16px;
        margin-bottom: 20px;
        border: 1px solid rgba(216, 79, 63, .3);
        border-radius: 12px;
        background: #fff0ee;
        color: var(--danger);
        font-size: 14px;
        font-weight: 600;
      }
      .footer {
        margin-top: 20px;
        text-align: center;
        color: var(--muted);
        font-size: 12px;
      }
    </style>
  </head>
  <body>
    <div class="login-card">
      <h1>IqroKu Admin</h1>
      <p>Masukkan admin token untuk mengakses dashboard.</p>
      ${error ? `<div class="error">${escapeHtml(error)}</div>` : ''}
      <form method="post" action="/admin/login">
        <label>
          Admin Token
          <input name="token" type="password" placeholder="Masukkan token..." required autofocus>
        </label>
        <button type="submit">Masuk</button>
      </form>
      <div class="footer">
        IqroKu &copy; ${new Date().getFullYear()}
      </div>
    </div>
  </body>
</html>`;
}

function renderAdminDashboard(metrics) {
  const cards = [
    ['Total Parent', metrics.totals.parents],
    ['Profil Anak', metrics.totals.children],
    ['Free Users', metrics.totals.freeParents],
    ['Plus Users', metrics.totals.plusParents],
    ['Subscription Aktif', metrics.totals.activeSubscriptions],
    ['MRR Estimasi', rupiah(metrics.totals.monthlyRevenue)],
    ['Rekaman Bacaan', metrics.totals.attempts],
    ['Assessment Selesai', metrics.totals.assessedAttempts],
    ['Pending Assessment', metrics.totals.pendingAttempts],
    ['Parent Aktif Hari Ini', metrics.totals.activeParentsToday],
    ['Halaman Lancar', metrics.totals.fluentPages],
    ['Perlu Ulang', metrics.totals.reviewPages],
  ];

  return `<!doctype html>
<html lang="id">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>IqroKu Admin</title>
    <style>
      :root {
        color-scheme: light;
        --canvas: #f8f6ef;
        --surface: #ffffff;
        --paper: #fffbf1;
        --line: #e7e1d6;
        --text: #17201b;
        --muted: #6d756f;
        --primary: #23864b;
        --primary-dark: #0f5b39;
        --gold: #e2a83b;
        --coral: #e66c55;
        --blue: #4f8cc9;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        color: var(--text);
        background: linear-gradient(180deg, var(--canvas), #fff);
      }
      main {
        width: min(1180px, calc(100% - 32px));
        margin: 0 auto;
        padding: 28px 0 44px;
      }
      header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 16px;
        margin-bottom: 22px;
      }
      h1, h2 { margin: 0; letter-spacing: 0; }
      h1 { font-size: 28px; }
      h2 { font-size: 18px; margin-bottom: 12px; }
      p { margin: 6px 0 0; color: var(--muted); }
      a {
        color: var(--primary);
        font-weight: 800;
        text-decoration: none;
      }
      .badge {
        display: inline-flex;
        align-items: center;
        border: 1px solid rgba(35, 134, 75, .22);
        border-radius: 999px;
        padding: 8px 12px;
        color: var(--primary-dark);
        background: #e7f5ec;
        font-size: 13px;
        font-weight: 800;
        white-space: nowrap;
      }
      .grid {
        display: grid;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: 12px;
      }
      .card, section {
        background: var(--surface);
        border: 1px solid var(--line);
        border-radius: 16px;
        box-shadow: 0 6px 14px rgba(0, 0, 0, .06);
      }
      .card { padding: 16px; }
      .card span {
        display: block;
        color: var(--muted);
        font-size: 12px;
        font-weight: 700;
      }
      .card strong {
        display: block;
        margin-top: 7px;
        font-size: 24px;
      }
      section {
        margin-top: 18px;
        overflow: hidden;
      }
      .section-head {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 12px;
        padding: 16px;
        background: var(--paper);
        border-bottom: 1px solid var(--line);
      }
      table {
        width: 100%;
        border-collapse: collapse;
      }
      th, td {
        padding: 12px 16px;
        border-bottom: 1px solid var(--line);
        text-align: left;
        font-size: 13px;
        vertical-align: top;
      }
      th {
        color: var(--muted);
        font-size: 12px;
        text-transform: uppercase;
        letter-spacing: .04em;
      }
      tr:last-child td { border-bottom: 0; }
      .pill {
        display: inline-flex;
        padding: 5px 9px;
        border-radius: 999px;
        background: rgba(35, 134, 75, .12);
        color: var(--primary);
        font-size: 12px;
        font-weight: 800;
      }
      .pill.free { background: rgba(141, 148, 143, .14); color: var(--muted); }
      .pill.pending { background: rgba(226, 168, 59, .16); color: #8b6412; }
      .pill.review { background: rgba(230, 108, 85, .14); color: var(--coral); }
      .muted { color: var(--muted); }
      .empty {
        padding: 18px 16px;
        color: var(--muted);
      }
      @media (max-width: 920px) {
        .grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        header { flex-direction: column; }
        table { display: block; overflow-x: auto; }
      }
    </style>
  </head>
  <body>
    <main>
      <header>
        <div>
          <h1>IqroKu Admin</h1>
          <p>Prototype dashboard untuk user, subscription, revenue, rekaman, dan assessment.</p>
        </div>
        <div>
          <span class="badge">Generated ${escapeHtml(formatDateTime(metrics.generatedAt))}</span>
          <p><a href="/admin/prayers">Kelola Doa</a> · <a href="/admin/metrics">View JSON metrics</a> · <a href="/admin/logout">Logout</a></p>
        </div>
      </header>

      <div class="grid">
        ${cards.map(([label, value]) => `
          <div class="card">
            <span>${escapeHtml(label)}</span>
            <strong>${escapeHtml(String(value))}</strong>
          </div>
        `).join('')}
      </div>

      ${renderParentsTable(metrics.parents)}
      ${renderSubscriptionsTable(metrics.subscriptions, metrics.parents)}
      ${renderAttemptsTable(metrics.attempts)}
    </main>
  </body>
</html>`;
}

function renderAdminPrayers(prayers, notice = '') {
  return `<!doctype html>
<html lang="id">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Kelola Doa - IqroKu Admin</title>
    <style>
      :root {
        color-scheme: light;
        --canvas: #f8f6ef;
        --surface: #ffffff;
        --paper: #fffbf1;
        --line: #e7e1d6;
        --text: #17201b;
        --muted: #6d756f;
        --primary: #23864b;
        --primary-dark: #0f5b39;
        --danger: #d84f3f;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        color: var(--text);
        background: linear-gradient(180deg, var(--canvas), #fff);
      }
      main {
        width: min(980px, calc(100% - 32px));
        margin: 0 auto;
        padding: 28px 0 44px;
      }
      header {
        display: flex;
        justify-content: space-between;
        gap: 16px;
        align-items: flex-start;
        margin-bottom: 18px;
      }
      h1, h2, h3 { margin: 0; letter-spacing: 0; }
      h1 { font-size: 28px; }
      h2 { font-size: 18px; }
      h3 { font-size: 16px; }
      p { margin: 6px 0 0; color: var(--muted); }
      a {
        color: var(--primary);
        font-weight: 800;
        text-decoration: none;
      }
      section, .prayer {
        background: var(--surface);
        border: 1px solid var(--line);
        border-radius: 16px;
        box-shadow: 0 6px 14px rgba(0, 0, 0, .06);
      }
      section { padding: 16px; margin-bottom: 16px; }
      .notice {
        padding: 12px 14px;
        margin-bottom: 16px;
        border: 1px solid rgba(35, 134, 75, .2);
        border-radius: 12px;
        background: #e7f5ec;
        color: var(--primary-dark);
        font-weight: 800;
      }
      .grid {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 12px;
      }
      label {
        display: grid;
        gap: 7px;
        color: var(--muted);
        font-size: 12px;
        font-weight: 800;
      }
      input, textarea {
        width: 100%;
        border: 1px solid var(--line);
        border-radius: 12px;
        padding: 11px 12px;
        color: var(--text);
        background: #fff;
        font: inherit;
      }
      textarea { min-height: 96px; resize: vertical; }
      .wide { grid-column: 1 / -1; }
      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        align-items: center;
        margin-top: 12px;
      }
      button {
        border: 0;
        border-radius: 999px;
        padding: 10px 15px;
        background: var(--primary);
        color: #fff;
        font-weight: 900;
        cursor: pointer;
      }
      button.secondary {
        background: #edf6f0;
        color: var(--primary-dark);
      }
      button.danger {
        background: #fff0ee;
        color: var(--danger);
      }
      .check {
        display: inline-flex;
        grid-auto-flow: column;
        align-items: center;
        gap: 8px;
        color: var(--text);
      }
      .check input { width: auto; }
      .prayer {
        padding: 16px;
        margin-bottom: 12px;
      }
      .prayer-head {
        display: flex;
        justify-content: space-between;
        gap: 12px;
        margin-bottom: 12px;
      }
      .pill {
        display: inline-flex;
        align-items: center;
        height: 28px;
        padding: 0 10px;
        border-radius: 999px;
        background: rgba(35, 134, 75, .12);
        color: var(--primary);
        font-size: 12px;
        font-weight: 900;
        white-space: nowrap;
      }
      .pill.off {
        background: rgba(109, 117, 111, .14);
        color: var(--muted);
      }
      .empty {
        padding: 18px 0;
        color: var(--muted);
      }
      @media (max-width: 720px) {
        header { flex-direction: column; }
        .grid { grid-template-columns: 1fr; }
      }
    </style>
  </head>
  <body>
    <main>
      <header>
        <div>
          <h1>Kelola Doa</h1>
          <p>Update konten Doa-doa dari dashboard, lalu aplikasi akan mengambil data terbaru dari backend.</p>
        </div>
        <p><a href="/admin">Dashboard</a> · <a href="/daily-prayers">JSON publik</a></p>
      </header>

      ${notice ? `<div class="notice">${escapeHtml(notice)}</div>` : ''}

      <section>
        <h2>Tambah Doa Baru</h2>
        <p>Isi minimal judul, Arab, dan arti. Urutan kecil tampil lebih atas.</p>
        <form method="post" action="/admin/prayers">
          ${renderPrayerFields({
            title: '',
            category: 'Harian',
            arabic: '',
            latin: '',
            meaning: '',
            sortOrder: nextPrayerSortOrder(prayers),
            active: true,
          })}
          <div class="actions">
            <button type="submit">Simpan Doa</button>
          </div>
        </form>
      </section>

      <section>
        <h2>Daftar Doa</h2>
        <p>${prayers.length} konten doa tersimpan.</p>
      </section>

      ${prayers.length ? prayers.map(renderPrayerEditor).join('') : '<div class="empty">Belum ada doa.</div>'}
    </main>
  </body>
</html>`;
}

function renderPrayerEditor(prayer) {
  return `<div class="prayer">
    <div class="prayer-head">
      <div>
        <h3>${escapeHtml(prayer.title)}</h3>
        <p>${escapeHtml(prayer.category || 'Harian')} · Urutan ${escapeHtml(prayer.sortOrder ?? 0)}</p>
      </div>
      <span class="pill ${prayer.active === false ? 'off' : ''}">${prayer.active === false ? 'Nonaktif' : 'Aktif'}</span>
    </div>
    <form method="post" action="/admin/prayers/${encodeURIComponent(prayer.id)}/update">
      ${renderPrayerFields(prayer)}
      <div class="actions">
        <button type="submit">Update</button>
      </div>
    </form>
    <form method="post" action="/admin/prayers/${encodeURIComponent(prayer.id)}/delete">
      <div class="actions">
        <button class="danger" type="submit">Hapus</button>
      </div>
    </form>
  </div>`;
}

function renderPrayerFields(prayer) {
  return `<div class="grid">
    <label>
      Judul
      <input name="title" required value="${escapeHtml(prayer.title)}">
    </label>
    <label>
      Kategori
      <input name="category" value="${escapeHtml(prayer.category)}">
    </label>
    <label class="wide">
      Teks Arab
      <textarea name="arabic" required dir="rtl">${escapeHtml(prayer.arabic)}</textarea>
    </label>
    <label class="wide">
      Latin
      <textarea name="latin">${escapeHtml(prayer.latin)}</textarea>
    </label>
    <label class="wide">
      Arti Indonesia
      <textarea name="meaning" required>${escapeHtml(prayer.meaning)}</textarea>
    </label>
    <label>
      Urutan
      <input name="sortOrder" type="number" value="${escapeHtml(prayer.sortOrder ?? 100)}">
    </label>
    <label class="check">
      <input name="active" type="checkbox" ${prayer.active === false ? '' : 'checked'}>
      Aktif tampil di app
    </label>
  </div>`;
}

function nextPrayerSortOrder(prayers) {
  const maxSort = prayers.reduce((max, prayer) => {
    return Math.max(max, Number(prayer.sortOrder ?? 0));
  }, 0);
  return maxSort + 10;
}

function renderParentsTable(parents) {
  return `<section>
    <div class="section-head">
      <h2>Users Parent</h2>
      <span class="muted">${parents.length} user</span>
    </div>
    ${parents.length ? `<table>
      <thead>
        <tr>
          <th>Nama</th>
          <th>Email</th>
          <th>Plan</th>
          <th>Anak</th>
          <th>Created</th>
        </tr>
      </thead>
      <tbody>
        ${parents.map((parent) => `
          <tr>
            <td>${escapeHtml(parent.name)}</td>
            <td>${escapeHtml(parent.email)}</td>
            <td><span class="pill ${parent.plan === 'Free' ? 'free' : ''}">${escapeHtml(parent.plan)}</span></td>
            <td>${parent.childrenCount}</td>
            <td>${escapeHtml(formatDateTime(parent.createdAt))}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>` : '<div class="empty">Belum ada user parent.</div>'}
  </section>`;
}

function renderSubscriptionsTable(subscriptions, parents) {
  const parentById = new Map(parents.map((parent) => [parent.id, parent]));
  return `<section>
    <div class="section-head">
      <h2>Subscriptions</h2>
      <span class="muted">${subscriptions.length} subscription</span>
    </div>
    ${subscriptions.length ? `<table>
      <thead>
        <tr>
          <th>Parent</th>
          <th>Plan</th>
          <th>Status</th>
          <th>Aktif</th>
          <th>Sampai</th>
        </tr>
      </thead>
      <tbody>
        ${subscriptions.map((subscription) => {
          const parent = parentById.get(subscription.parentId);
          return `<tr>
            <td>${escapeHtml(parent?.email ?? subscription.parentId)}</td>
            <td>${escapeHtml(subscription.plan ?? '-')}</td>
            <td><span class="pill ${subscription.active ? '' : 'free'}">${subscription.active ? 'Aktif' : 'Tidak aktif'}</span></td>
            <td>${escapeHtml(formatDateTime(subscription.activatedAt))}</td>
            <td>${escapeHtml(formatDateTime(subscription.activeUntil))}</td>
          </tr>`;
        }).join('')}
      </tbody>
    </table>` : '<div class="empty">Belum ada subscription.</div>'}
  </section>`;
}

function renderAttemptsTable(attempts) {
  return `<section>
    <div class="section-head">
      <h2>Rekaman & Assessment Terbaru</h2>
      <span class="muted">${attempts.length} terbaru</span>
    </div>
    ${attempts.length ? `<table>
      <thead>
        <tr>
          <th>Anak</th>
          <th>Parent</th>
          <th>Materi</th>
          <th>Status</th>
          <th>Skor</th>
          <th>Created</th>
        </tr>
      </thead>
      <tbody>
        ${attempts.map((attempt) => `
          <tr>
            <td>${escapeHtml(attempt.childName)}</td>
            <td>${escapeHtml(attempt.parentEmail)}</td>
            <td>Iqro ${attempt.bookId} - Halaman ${attempt.pageNumber}</td>
            <td>${renderAttemptStatus(attempt.assessmentStatus)}</td>
            <td>${attempt.score ?? '-'}</td>
            <td>${escapeHtml(formatDateTime(attempt.createdAt ?? attempt.assessedAt))}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>` : '<div class="empty">Belum ada rekaman bacaan.</div>'}
  </section>`;
}

function renderAttemptStatus(status = 'recorded') {
  const className = status === 'recorded' ? 'pending' : status === 'needsReview' ? 'review' : '';
  return `<span class="pill ${className}">${escapeHtml(status)}</span>`;
}

function childName(state, childId) {
  return state.children.find((child) => child.id === childId)?.name ?? 'Unknown';
}

function childParentId(state, childId) {
  return state.children.find((child) => child.id === childId)?.parentId ?? '';
}

function childParentEmail(state, childId) {
  const parentId = childParentId(state, childId);
  return state.parents.find((parent) => parent.id === parentId)?.email ?? '-';
}

function sameDay(value, yyyyMmDd) {
  return typeof value === 'string' && value.slice(0, 10) === yyyyMmDd;
}

function compareDateDesc(a, b) {
  return String(b ?? '').localeCompare(String(a ?? ''));
}

function formatDateTime(value) {
  if (!value) {
    return '-';
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '-';
  }
  return date.toLocaleString('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

function rupiah(value) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function now() {
  return new Date().toISOString();
}

function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function logRequest(method, path, status, ms, ip) {
  console.log(JSON.stringify({
    ts: new Date().toISOString(),
    method,
    path,
    status,
    ms,
    ip,
  }));
}
