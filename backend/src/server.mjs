import { createServer } from 'node:http';
import { createHash, randomBytes, randomUUID, scryptSync, timingSafeEqual } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import * as db from './db.mjs';
import * as push from './push.mjs';

// Initialize PostgreSQL connection
const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.error('ERROR: DATABASE_URL environment variable is required.');
  console.error('Example: DATABASE_URL=postgresql://iqroku:pass@localhost:5432/iqroku_db');
  process.exit(1);
}
db.initDb(DATABASE_URL);

const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || 'https://iqroku.motionmind.store';
const ENABLE_DEMO_LOGIN = process.env.ENABLE_DEMO_LOGIN === 'true';
const REQUIRE_EMAIL_VERIFICATION = process.env.REQUIRE_EMAIL_VERIFICATION === 'true';
const AUTH_LINK_BASE_URL = process.env.AUTH_LINK_BASE_URL || ALLOWED_ORIGIN;
const EMAIL_VERIFICATION_TTL_MINUTES = Number(process.env.EMAIL_VERIFICATION_TTL_MINUTES ?? 60 * 24);
const PASSWORD_RESET_TTL_MINUTES = Number(process.env.PASSWORD_RESET_TTL_MINUTES ?? 30);

// Google Sign-In: the audience the client's idToken must be issued for.
// Defaults to the serverClientId used by the Flutter app.
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID
  || '55523615051-81vpiqk0jiamubrnjb0ss4i6irpifm2t.apps.googleusercontent.com';

const port = Number(process.env.PORT ?? 8787);
const ADMIN_TOKEN = process.env.IQROKU_ADMIN_TOKEN || 'admin-dev-token';
if (ADMIN_TOKEN === 'admin-dev-token' && process.env.NODE_ENV === 'production') {
  console.error('FATAL: IQROKU_ADMIN_TOKEN must be set in production. Refusing to start with default token.');
  process.exit(1);
}
const ADMIN_ALLOWED_IPS = new Set(
  String(process.env.ADMIN_ALLOWED_IPS ?? '')
    .split(/[,\s]+/)
    .map((value) => value.trim())
    .filter(Boolean),
);
const MAX_BODY_SIZE = Number(process.env.MAX_BODY_SIZE) || 5 * 1024 * 1024; // 5MB max request body
const MAX_AUDIO_UPLOAD_BYTES = Number(process.env.MAX_AUDIO_UPLOAD_BYTES) || MAX_BODY_SIZE;
const MAX_STRING_LENGTH = 500; // max string field length
const UPLOAD_ROOT = resolve(process.env.IQROKU_UPLOAD_ROOT || 'uploads');
const AUDIO_UPLOAD_DIR = resolve(UPLOAD_ROOT, 'audio');
const ALLOWED_AUDIO_CONTENT_TYPES = new Set([
  'audio/aac',
  'audio/m4a',
  'audio/mp4',
  'audio/mpeg',
  'audio/x-aac',
  'audio/x-m4a',
  'audio/x-mp4',
  'audio/wav',
  'audio/webm',
  'audio/x-wav',
  'audio/3gpp',
  'video/mp4',
]);
const GENERIC_AUDIO_UPLOAD_CONTENT_TYPES = new Set([
  '',
  'application/octet-stream',
  'binary/octet-stream',
]);
const ALLOWED_AUDIO_EXTENSIONS = new Set(['.aac', '.m4a', '.mp3', '.mp4', '.wav', '.webm']);

// --- Rate Limiter ---
const rateLimits = new Map();
const RATE_WINDOW_MS = Number(process.env.RATE_WINDOW_MS) || 60_000; // 1 minute
const RATE_MAX_AUTH = Number(process.env.RATE_MAX_AUTH) || 10; // max auth attempts per IP per minute
const RATE_MAX_DEMO = 5; // max demo-login attempts per IP per minute
const RATE_MAX_GENERAL = Number(process.env.RATE_MAX_GENERAL) || 120; // max general requests per IP per minute
const CLEANUP_EXPIRED_AUTH_INTERVAL_MS = Number(
  process.env.CLEANUP_EXPIRED_AUTH_INTERVAL_MS ?? 6 * 60 * 60 * 1000,
);

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

async function cleanupExpiredAuthData() {
  try {
    await db.cleanupExpiredSessions();
    await db.cleanupExpiredAuthTokens();
  } catch (error) {
    console.error('Expired auth data cleanup failed:', error.message);
  }
}

if (CLEANUP_EXPIRED_AUTH_INTERVAL_MS > 0) {
  setInterval(cleanupExpiredAuthData, CLEANUP_EXPIRED_AUTH_INTERVAL_MS).unref();
  setTimeout(cleanupExpiredAuthData, 10_000).unref();
}

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

// Constant-time string comparison to avoid leaking the admin token via timing.
function safeStrEqual(a, b) {
  const bufA = Buffer.from(String(a));
  const bufB = Buffer.from(String(b));
  if (bufA.length !== bufB.length) {
    // Compare against itself to keep the timing roughly constant, then fail.
    timingSafeEqual(bufA, bufA);
    return false;
  }
  return timingSafeEqual(bufA, bufB);
}

function secureCookieAttribute() {
  return process.env.NODE_ENV === 'production' ? '; Secure' : '';
}

// Verify a Google Sign-In ID token with Google and return its trusted claims.
// Never trust email/sub coming from the request body — only what Google signs.
async function verifyGoogleIdToken(idToken) {
  if (!idToken) {
    throw httpError(400, 'missing_id_token');
  }
  let payload;
  try {
    const res = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
    );
    if (!res.ok) {
      throw httpError(401, 'invalid_google_token');
    }
    payload = await res.json();
  } catch (err) {
    if (err.statusCode) throw err;
    throw httpError(502, 'google_verification_failed');
  }

  // aud must match our client id; iss must be Google; email must be present+verified.
  if (payload.aud !== GOOGLE_CLIENT_ID) {
    throw httpError(401, 'google_token_wrong_audience');
  }
  if (payload.iss !== 'accounts.google.com' && payload.iss !== 'https://accounts.google.com') {
    throw httpError(401, 'google_token_wrong_issuer');
  }
  if (payload.exp && Number(payload.exp) * 1000 < Date.now()) {
    throw httpError(401, 'google_token_expired');
  }
  if (!payload.email || payload.email_verified === 'false' || payload.email_verified === false) {
    throw httpError(401, 'google_email_unverified');
  }
  return { email: String(payload.email), sub: String(payload.sub), name: payload.name };
}

function authenticateAdmin(request) {
  const authHeader = request.headers?.['authorization'] ?? '';
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice(7).trim()
    : '';

  // Check cookie
  const cookie = request.headers?.['cookie'] ?? '';
  const cookieToken = cookie.match(/admin_token=([^;]+)/)?.[1] ?? '';

  if (!safeStrEqual(token, ADMIN_TOKEN) && !safeStrEqual(cookieToken, ADMIN_TOKEN)) {
    throw httpError(403, 'admin_access_denied');
  }
}

function enforceAdminIpAllowlist(request) {
  if (ADMIN_ALLOWED_IPS.size === 0) {
    return;
  }
  const clientIp = getClientIp(request);
  if (!ADMIN_ALLOWED_IPS.has(clientIp)) {
    throw httpError(403, 'admin_ip_not_allowed');
  }
}

// Behind a reverse proxy (nginx) every request's socket address is the proxy
// itself, so rate limiting on remoteAddress buckets ALL users into one counter.
// Trust the first hop in X-Forwarded-For (set by our nginx) for the real IP.
const TRUST_PROXY = (process.env.TRUST_PROXY ?? 'true') !== 'false';
function getClientIp(request) {
  if (TRUST_PROXY) {
    const fwd = request.headers?.['x-forwarded-for'];
    if (typeof fwd === 'string' && fwd.length > 0) {
      const first = fwd.split(',')[0].trim();
      if (first) return normalizeClientIp(first);
    }
  }
  return normalizeClientIp(request.socket?.remoteAddress ?? 'unknown');
}

function normalizeClientIp(value) {
  return String(value).replace(/^::ffff:/, '');
}

const server = createServer(async (request, response) => {
  const clientIp = getClientIp(request);
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

  if (path === '/admin' || path.startsWith('/admin/')) {
    enforceAdminIpAllowlist(request);
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
    if (!safeStrEqual(token, ADMIN_TOKEN)) {
      return { html: renderAdminLogin('Token salah. Silakan coba lagi.') };
    }
    return {
      status: 302,
      headers: {
        'Set-Cookie': `admin_token=${token}; Path=/admin; HttpOnly; SameSite=Strict; Max-Age=86400${secureCookieAttribute()}`,
        'Location': '/admin',
      },
      body: '',
    };
  }

  if (method === 'GET' && path === '/admin/logout') {
    return {
      status: 302,
      headers: {
        'Set-Cookie': `admin_token=; Path=/admin; HttpOnly; SameSite=Strict; Max-Age=0${secureCookieAttribute()}`,
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
    const authedParent = await authenticateRequest(request);
    const fileName = safeStoredFileName(path.split('/').pop() ?? '');
    const attempt = await db.findAttemptByAudioFileName(fileName);
    if (!attempt) {
      throw httpError(404, 'file_not_found');
    }
    await enforceChildOwnership(authedParent.id, attempt.childId);
    return {
      filePath: resolve(AUDIO_UPLOAD_DIR, fileName),
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
    if (!ENABLE_DEMO_LOGIN) {
      throw httpError(404, 'not_found');
    }
    const email = cleanString(body.email) || 'parent@iqroku.local';
    const name = cleanString(body.name) || 'Orang Tua';
    const demoEmail = normalizeDemoEmail(email);
    const existing = await db.findParentByEmail(demoEmail);
    if (existing) {
      throw httpError(409, 'demo_account_exists');
    }
    const parent = await db.createParent({ id: randomUUID(), email: demoEmail, name });
    const token = createSessionToken();
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
    const verification = await createAuthFlowToken(parent, 'email_verification', EMAIL_VERIFICATION_TTL_MINUTES);
    emitAuthFlowToken({
      type: 'email_verification',
      email,
      token: verification.token,
      path: '/auth/verify-email',
    });
    const token = createSessionToken();
    await storeSession(token, parent.id);
    return {
      status: 201,
      body: {
        parent: publicParent(parent),
        session: { token, type: 'password' },
        emailVerification: authFlowResponse(verification, {
          required: REQUIRE_EMAIL_VERIFICATION,
        }),
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
    if (REQUIRE_EMAIL_VERIFICATION && !parent.emailVerified) {
      throw httpError(403, 'email_not_verified');
    }

    const token = createSessionToken();
    await storeSession(token, parent.id);
    return {
      parent: publicParent(parent),
      session: { token, type: 'password' },
    };
  }

  if (method === 'POST' && path === '/auth/google') {
    const idToken = cleanString(requiredBody(body, 'idToken'));

    // Verify the token with Google and derive identity from the SIGNED claims,
    // not from anything the client sent in the body.
    const claims = await verifyGoogleIdToken(idToken);
    const email = normalizeEmail(claims.email);
    const googleId = cleanString(claims.sub);
    const name = truncateString(cleanString(claims.name || body.name) || 'User');

    if (!googleId) {
      throw httpError(401, 'invalid_google_token');
    }

    // Try to find existing user by email
    let parent = await db.findParentByEmail(email);

    if (parent) {
      // Update Google ID if not set
      if (!parent.googleId) {
        parent = await db.updateParent(parent.id, { googleId });
      }
      if (!parent.emailVerified) {
        parent = await db.markParentEmailVerified(parent.id);
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

    const token = createSessionToken();
    await storeSession(token, parent.id);
    return {
      parent: publicParent(parent),
      session: { token, type: 'google' },
    };
  }

  if (method === 'POST' && path === '/auth/verify-email') {
    const token = cleanString(requiredBody(body, 'token'));
    const parent = await consumeAuthFlowToken('email_verification', token);
    const verified = await db.markParentEmailVerified(parent.id);
    return { ok: true, parent: publicParent(verified) };
  }

  if (method === 'POST' && path === '/auth/resend-verification') {
    const email = normalizeEmail(requiredBody(body, 'email'));
    const parent = await db.findParentByEmail(email);
    let flow;
    if (parent && !parent.emailVerified) {
      await db.revokeAuthTokens(parent.id, 'email_verification');
      const verification = await createAuthFlowToken(parent, 'email_verification', EMAIL_VERIFICATION_TTL_MINUTES);
      flow = authFlowResponse(verification);
      emitAuthFlowToken({
        type: 'email_verification',
        email,
        token: verification.token,
        path: '/auth/verify-email',
      });
    }
    return { ok: true, emailVerification: flow };
  }

  if (method === 'POST' && path === '/auth/password-reset/request') {
    const email = normalizeEmail(requiredBody(body, 'email'));
    const parent = await db.findParentByEmail(email);
    let flow;
    if (parent?.passwordHash) {
      await db.revokeAuthTokens(parent.id, 'password_reset');
      const reset = await createAuthFlowToken(parent, 'password_reset', PASSWORD_RESET_TTL_MINUTES);
      flow = authFlowResponse(reset);
      emitAuthFlowToken({
        type: 'password_reset',
        email,
        token: reset.token,
        path: '/auth/password-reset/confirm',
      });
    }
    return { ok: true, passwordReset: flow };
  }

  if (method === 'POST' && path === '/auth/password-reset/confirm') {
    const token = cleanString(requiredBody(body, 'token'));
    const password = cleanString(requiredBody(body, 'password'));
    validatePassword(password);
    const parent = await consumeAuthFlowToken('password_reset', token);
    await db.updateParentPassword(parent.id, hashPassword(password));
    await db.revokeAuthTokens(parent.id, 'password_reset');
    return { ok: true };
  }

  // --- Protected routes (require user auth) ---
  if (method === 'GET' && path === '/children') {
    const authedParent = await authenticateRequest(request);
    const parentId = requiredQuery(url, 'parentId');
    if (parentId !== authedParent.id) {
      throw httpError(403, 'access_denied');
    }
    const children = await db.findChildrenByParent(parentId);
    return children.map(publicChild);
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
    return { status: 201, body: publicChild(child) };
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
    const bookId = clampNumber(Number(requiredBody(body, 'bookId')), 1, 99);
    const pageNumber = clampNumber(Number(requiredBody(body, 'pageNumber')), 1, 999);

    const attempt = await db.createAttempt({
      id: attemptId,
      childId,
      bookId,
      pageNumber,
      durationSeconds: clampNumber(Number(body.durationSeconds ?? 1), 1, 3600),
      audioPath: cleanString(body.audioPath) || null,
    });

    // Notify parent about new recording
    try {
      const child = await db.findChildById(childId);
      if (child) {
        const notification = await db.createNotification({
          userId: child.parentId,
          userType: 'parent',
          type: 'new_recording',
          title: `${child.name} sudah merekam`,
          message: `${child.name} telah membaca Iqro ${bookId} halaman ${pageNumber}`,
          data: { childId, bookId, pageNumber, attemptId },
        });
        queuePushNotification(notification);
      }
    } catch (err) {
      console.error('Failed to create notification:', err);
    }

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
    throw httpError(410, 'assessment_disabled');
  }

  if (method === 'POST' && path === '/assessments/ai') {
    throw httpError(410, 'assessment_disabled');
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

  // --- PIN Management ---
  if (method === 'POST' && path === '/auth/set-parent-pin') {
    const authedParent = await authenticateRequest(request);
    const pin = cleanString(body.pin);
    if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
      throw httpError(400, 'invalid_pin');
    }
    const pinHash = hashPassword(pin);
    await db.setParentPin(authedParent.id, pinHash);
    return { ok: true, message: 'PIN berhasil diset' };
  }

  if (method === 'POST' && path === '/auth/verify-parent-pin') {
    const authedParent = await authenticateRequest(request);
    const pin = cleanString(body.pin);
    if (!pin) {
      throw httpError(400, 'missing_pin');
    }
    const parent = await db.findParentById(authedParent.id);
    if (!parent?.pinHash) {
      throw httpError(400, 'pin_not_set');
    }
    const valid = verifyPassword(pin, parent.pinHash);
    return { valid };
  }

  if (method === 'POST' && path === '/auth/child-login') {
    const authedParent = await authenticateRequest(request);
    const childId = cleanString(body.childId);
    const pin = cleanString(body.pin);
    if (!childId || !pin) {
      throw httpError(400, 'missing_child_id_or_pin');
    }
    await enforceChildOwnership(authedParent.id, childId);
    const child = await db.findChildById(childId);
    if (!child?.pinHash) {
      throw httpError(400, 'child_pin_not_set');
    }
    const valid = verifyPassword(pin, child.pinHash);
    if (!valid) {
      throw httpError(401, 'invalid_pin');
    }
    return { valid: true, child: publicChild(child) };
  }

  const childPinAction = childSetPinAction(path);
  if (method === 'POST' && childPinAction) {
    const authedParent = await authenticateRequest(request);
    const childId = childPinAction.id;
    await enforceChildOwnership(authedParent.id, childId);
    const pin = cleanString(body.pin);
    if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
      throw httpError(400, 'invalid_pin');
    }
    const pinHash = hashPassword(pin);
    const child = await db.setChildPin(childId, pinHash);
    return { ok: true, child: publicChild(child) };
  }

  const childSchedule = childScheduleAction(path);
  if (method === 'POST' && childSchedule) {
    const authedParent = await authenticateRequest(request);
    const childId = childSchedule.id;
    await enforceChildOwnership(authedParent.id, childId);
    const startTime = cleanString(body.startTime);
    const endTime = cleanString(body.endTime);
    const days = Array.isArray(body.days) ? body.days : [1, 2, 3, 4, 5];
    const child = await db.updateChildSchedule(childId, startTime, endTime, days);
    return { ok: true, child: publicChild(child) };
  }

  // --- Review System ---
  if (method === 'GET' && path === '/reviews/pending') {
    const authedParent = await authenticateRequest(request);
    return db.getPendingReviews(authedParent.id);
  }

  if (method === 'POST' && path === '/reviews/approve') {
    const authedParent = await authenticateRequest(request);
    const attemptId = requiredBody(body, 'attemptId');
    const attempt = await db.findAttemptById(attemptId);
    if (!attempt) {
      throw httpError(404, 'attempt_not_found');
    }
    await enforceChildOwnership(authedParent.id, attempt.childId);

    const notification = await db.approveReview({
      attempt,
      reviewedBy: authedParent.id,
    });
    queuePushNotification(notification);
    return { ok: true, status: 'approved' };
  }

  if (method === 'POST' && path === '/reviews/repeat') {
    const authedParent = await authenticateRequest(request);
    const attemptId = requiredBody(body, 'attemptId');
    const fromPage = Number(body.fromPage);
    if (!Number.isInteger(fromPage) || fromPage < 1) {
      throw httpError(400, 'invalid_repeat_page');
    }
    const attempt = await db.findAttemptById(attemptId);
    if (!attempt) {
      throw httpError(404, 'attempt_not_found');
    }
    await enforceChildOwnership(authedParent.id, attempt.childId);
    if (fromPage > attempt.pageNumber) {
      throw httpError(400, 'invalid_repeat_page');
    }

    const notification = await db.repeatReview({
      attempt,
      reviewedBy: authedParent.id,
      fromPage,
    });
    queuePushNotification(notification);
    return { ok: true, status: 'needs_repeat', fromPage };
  }

  // --- Device tokens for push notifications ---
  if (method === 'POST' && path === '/devices/register') {
    const authedParent = await authenticateRequest(request);
    const token = normalizeDeviceToken(requiredBody(body, 'token'));
    const platform = normalizeDevicePlatform(body.platform);
    const userType = cleanString(body.userType) || 'parent';
    const childId = cleanString(body.childId);

    if (!['parent', 'child'].includes(userType)) {
      throw httpError(400, 'invalid_user_type');
    }
    if (userType === 'child') {
      if (!childId) {
        throw httpError(400, 'missing_childId');
      }
      await enforceChildOwnership(authedParent.id, childId);
    }

    await db.upsertDeviceToken({
      parentId: authedParent.id,
      childId: userType === 'child' ? childId : null,
      userType,
      token,
      platform,
      appVersion: truncateString(cleanString(body.appVersion)).slice(0, 80),
      deviceModel: truncateString(cleanString(body.deviceModel)).slice(0, 200),
    });
    return { ok: true, pushConfigured: push.pushConfigured() };
  }

  if (method === 'POST' && path === '/devices/unregister') {
    const authedParent = await authenticateRequest(request);
    const token = normalizeDeviceToken(requiredBody(body, 'token'));
    await db.disableDeviceToken({ parentId: authedParent.id, token });
    return { ok: true };
  }

  // --- Notifications ---
  if (method === 'GET' && path === '/notifications') {
    const authedParent = await authenticateRequest(request);
    const userType = url.searchParams.get('type') || 'parent';
    const childId = url.searchParams.get('childId');

    if (userType === 'child' && childId) {
      await enforceChildOwnership(authedParent.id, childId);
      return db.getNotifications(childId, 'child');
    }
    return db.getNotifications(authedParent.id, 'parent');
  }

  if (method === 'GET' && path === '/notifications/unread-count') {
    const authedParent = await authenticateRequest(request);
    const userType = url.searchParams.get('type') || 'parent';
    const childId = url.searchParams.get('childId');

    if (userType === 'child' && childId) {
      await enforceChildOwnership(authedParent.id, childId);
      return { count: await db.countUnreadNotifications(childId, 'child') };
    }
    return { count: await db.countUnreadNotifications(authedParent.id, 'parent') };
  }

  const notificationRead = notificationReadAction(path);
  if (method === 'POST' && notificationRead) {
    const authedParent = await authenticateRequest(request);
    const notification = await db.findNotificationById(notificationRead.id);
    if (!notification) {
      throw httpError(404, 'notification_not_found');
    }
    // Verify the notification belongs to this parent, or to one of their children.
    if (notification.user_type === 'child') {
      await enforceChildOwnership(authedParent.id, notification.user_id);
    } else if (notification.user_id !== authedParent.id) {
      throw httpError(403, 'access_denied');
    }
    await db.markNotificationRead(notification.id);
    return { ok: true };
  }

  if (method === 'POST' && path === '/notifications/read-all') {
    const authedParent = await authenticateRequest(request);
    const userType = cleanString(body.type) || 'parent';
    const childId = cleanString(body.childId);

    if (userType === 'child' && childId) {
      await enforceChildOwnership(authedParent.id, childId);
      await db.markAllNotificationsRead(childId, 'child');
    } else {
      await db.markAllNotificationsRead(authedParent.id, 'parent');
    }
    return { ok: true };
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
    'x-content-type-options': 'nosniff',
    'vary': 'Origin',
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
      'cache-control': 'private, no-store',
      'access-control-allow-origin': ALLOWED_ORIGIN,
      'x-content-type-options': 'nosniff',
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

function normalizeDeviceToken(value) {
  const token = cleanString(value);
  if (token.length < 20 || token.length > 4096 || /[\s\x00-\x1F]/.test(token)) {
    throw httpError(400, 'invalid_device_token');
  }
  return token;
}

function normalizeDevicePlatform(value) {
  const platform = cleanString(value).toLowerCase() || 'unknown';
  return ['android', 'ios', 'web'].includes(platform) ? platform : 'unknown';
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

function normalizeDemoEmail(value) {
  const email = normalizeEmail(value);
  if (!email.endsWith('@iqroku.local')) {
    throw httpError(400, 'demo_email_must_use_iqroku_local');
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

function createSessionToken() {
  return `session_${randomBytes(32).toString('base64url')}`;
}

function createOneTimeToken() {
  return randomBytes(32).toString('base64url');
}

function hashAuthToken(token) {
  return createHash('sha256').update(String(token)).digest('hex');
}

async function createAuthFlowToken(parent, purpose, ttlMinutes) {
  const token = createOneTimeToken();
  const expiresAt = addMinutes(new Date(), ttlMinutes).toISOString();
  await db.createAuthToken({
    parentId: parent.id,
    purpose,
    tokenHash: hashAuthToken(token),
    expiresAt,
    metadata: { email: parent.email },
  });
  return { token, expiresAt };
}

async function consumeAuthFlowToken(purpose, token) {
  const record = await db.findValidAuthToken({
    purpose,
    tokenHash: hashAuthToken(token),
  });
  if (!record) {
    throw httpError(400, 'invalid_or_expired_token');
  }
  await db.markAuthTokenUsed(record.id);
  const parent = await db.findParentById(record.parentId);
  if (!parent) {
    throw httpError(400, 'invalid_or_expired_token');
  }
  return parent;
}

function authFlowResponse(flow, extra = {}) {
  return {
    ...extra,
    expiresAt: flow.expiresAt,
    devToken: process.env.NODE_ENV === 'production' ? undefined : flow.token,
  };
}

function emitAuthFlowToken({ type, email, token, path }) {
  const link = `${AUTH_LINK_BASE_URL.replace(/\/$/, '')}${path}?token=${encodeURIComponent(token)}`;
  if (process.env.NODE_ENV === 'production') {
    console.log(JSON.stringify({
      ts: new Date().toISOString(),
      event: 'auth_token_created',
      type,
      email,
      delivery: 'pending_email_provider',
    }));
    return;
  }
  console.log(JSON.stringify({
    ts: new Date().toISOString(),
    event: 'auth_token_created',
    type,
    email,
    token,
    link,
  }));
}

function queuePushNotification(notification) {
  if (!notification) {
    return;
  }
  sendPushNotification(notification).catch((error) => {
    console.error('Failed to send push notification:', error.message);
  });
}

async function sendPushNotification(notification) {
  const userId = notification.user_id ?? notification.userId;
  const userType = notification.user_type ?? notification.userType;
  if (!userId || !userType) {
    return;
  }

  const devices = await db.getActiveDeviceTokens(userId, userType);
  const result = await push.sendPushToTokens({
    tokens: devices.map((device) => device.token),
    title: notification.title,
    body: notification.message,
    data: {
      notificationId: notification.id,
      type: notification.type,
      userType,
      ...(notification.data ?? {}),
    },
  });

  await Promise.all(
    result.invalidTokens.map((token) => db.disableDeviceTokenByToken(token)),
  );
}

function publicParent(parent) {
  const { passwordHash, pinHash, ...safeParent } = parent;
  return {
    ...safeParent,
    hasPin: Boolean(pinHash),
  };
}

function publicChild(child) {
  if (!child) return child;
  const { pinHash, ...safeChild } = child;
  return {
    ...safeChild,
    hasPin: Boolean(pinHash),
  };
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

function childSetPinAction(path) {
  const match = /^\/children\/([^/]+)\/set-pin$/.exec(path);
  if (!match) {
    return null;
  }
  return { id: decodeURIComponent(match[1]) };
}

function childScheduleAction(path) {
  const match = /^\/children\/([^/]+)\/schedule$/.exec(path);
  if (!match) {
    return null;
  }
  return { id: decodeURIComponent(match[1]) };
}

function notificationReadAction(path) {
  const match = /^\/notifications\/([^/]+)\/read$/.exec(path);
  if (!match) {
    return null;
  }
  return { id: decodeURIComponent(match[1]) };
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
  validateAudioUpload({ originalFileName, contentType, content });
  await mkdir(AUDIO_UPLOAD_DIR, { recursive: true });
  const extension = audioExtension(originalFileName, contentType);
  const fileName = safeStoredFileName(`${attemptId}-${Date.now()}${extension}`);
  await writeFile(resolve(AUDIO_UPLOAD_DIR, fileName), content);
  const normalizedType = contentType.split(';')[0].trim().toLowerCase();
  return {
    fileName,
    contentType: GENERIC_AUDIO_UPLOAD_CONTENT_TYPES.has(normalizedType)
      ? contentTypeForAudio(fileName)
      : contentType,
    sizeBytes: content.length,
    url: `/uploads/audio/${fileName}`,
  };
}

function validateAudioUpload({ originalFileName = '', contentType = '', content }) {
  if (!Buffer.isBuffer(content) || content.length === 0) {
    throw httpError(400, 'audio_file_empty');
  }
  if (content.length > MAX_AUDIO_UPLOAD_BYTES) {
    throw httpError(413, 'audio_file_too_large');
  }

  const normalizedType = contentType.split(';')[0].trim().toLowerCase();
  const genericBinaryUpload = GENERIC_AUDIO_UPLOAD_CONTENT_TYPES.has(normalizedType);
  if (!genericBinaryUpload && !ALLOWED_AUDIO_CONTENT_TYPES.has(normalizedType)) {
    throw httpError(415, 'unsupported_audio_type');
  }

  const extension = extname(originalFileName).toLowerCase();
  if (!extension || !ALLOWED_AUDIO_EXTENSIONS.has(extension)) {
    throw httpError(415, 'unsupported_audio_extension');
  }

  if (!looksLikeAudio(content)) {
    throw httpError(415, 'invalid_audio_file');
  }
}

function looksLikeAudio(content) {
  if (content.length < 12) {
    return false;
  }
  const ascii = content.subarray(0, 16).toString('latin1');
  if (ascii.startsWith('RIFF') && ascii.includes('WAVE')) return true;
  if (ascii.startsWith('ID3')) return true;
  if (content[0] === 0xff && (content[1] & 0xe0) === 0xe0) return true;
  if (ascii.includes('ftyp')) return true;
  if (ascii.startsWith('\x1aE\xdf\xa3')) return true;
  return false;
}

function audioExtension(fileName = '', contentType = '') {
  const extension = extname(fileName).toLowerCase();
  if (ALLOWED_AUDIO_EXTENSIONS.has(extension)) {
    return extension;
  }
  const normalizedType = contentType.split(';')[0].trim().toLowerCase();
  if (normalizedType.includes('mpeg')) {
    return '.mp3';
  }
  if (normalizedType.includes('wav')) {
    return '.wav';
  }
  if (normalizedType.includes('webm')) {
    return '.webm';
  }
  if (normalizedType.includes('3gpp')) {
    return '.aac';
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
    ['Pending Review', metrics.totals.pendingAttempts],
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
          <p>Prototype dashboard untuk user, subscription, revenue, rekaman, dan review.</p>
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

      ${renderParentsTable(metrics.parents, metrics.limits?.parents)}
      ${renderSubscriptionsTable(metrics.subscriptions, metrics.limits?.subscriptions)}
      ${renderAttemptsTable(metrics.attempts, metrics.limits?.attempts)}
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

function renderParentsTable(parents, limit) {
  return `<section>
    <div class="section-head">
      <h2>Users Parent</h2>
      <span class="muted">${parents.length}${limit ? `/${limit}` : ''} terbaru</span>
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

function renderSubscriptionsTable(subscriptions, limit) {
  return `<section>
    <div class="section-head">
      <h2>Subscriptions</h2>
      <span class="muted">${subscriptions.length}${limit ? `/${limit}` : ''} terbaru</span>
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
        ${subscriptions.map((subscription) => `
          <tr>
            <td>${escapeHtml(subscription.parentEmail || subscription.parentId)}</td>
            <td>${escapeHtml(subscription.plan ?? '-')}</td>
            <td><span class="pill ${subscription.active ? '' : 'free'}">${subscription.active ? 'Aktif' : 'Tidak aktif'}</span></td>
            <td>${escapeHtml(formatDateTime(subscription.activatedAt))}</td>
            <td>${escapeHtml(formatDateTime(subscription.activeUntil))}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>` : '<div class="empty">Belum ada subscription.</div>'}
  </section>`;
}

function renderAttemptsTable(attempts, limit) {
  return `<section>
    <div class="section-head">
      <h2>Rekaman & Review Terbaru</h2>
      <span class="muted">${attempts.length}${limit ? `/${limit}` : ''} terbaru</span>
    </div>
    ${attempts.length ? `<table>
      <thead>
        <tr>
          <th>Anak</th>
          <th>Parent</th>
          <th>Materi</th>
          <th>Status</th>
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
    .replaceAll("'", '&#39;')
    .replaceAll('`', '&#96;');
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

function addMinutes(date, minutes) {
  const next = new Date(date);
  next.setMinutes(next.getMinutes() + minutes);
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
