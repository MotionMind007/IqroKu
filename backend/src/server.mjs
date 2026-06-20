import { createServer } from 'node:http';
import { createHmac, randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import * as db from './db.mjs';
import * as push from './push.mjs';
import { fetchTextWithTimeoutAndRetry } from './external-fetch.mjs';
import { logError, logEvent, logRequest } from './observability.mjs';
import { createDokuPayments, DOKU_WEBHOOK_PATH } from './payments/doku.mjs';
import { createAuthServices } from './auth.mjs';
import { createAdminPanel } from './admin.mjs';
import { createLearningRoutes } from './learning.mjs';
import { createNotificationRoutes } from './notifications.mjs';
import { createFamilyRoutes } from './family.mjs';
import { createProgressRoutes } from './progress.mjs';
import { createBillingRoutes } from './billing.mjs';
import { createContentRoutes } from './content.mjs';

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
const RESEND_API_KEY = process.env.RESEND_API_KEY || '';
const EMAIL_PROVIDER = String(process.env.EMAIL_PROVIDER || (RESEND_API_KEY ? 'resend' : 'none')).toLowerCase();
const EMAIL_FROM = process.env.EMAIL_FROM || '';
const EMAIL_REPLY_TO = process.env.EMAIL_REPLY_TO || '';
const EMAIL_SEND_TIMEOUT_MS = Number(process.env.EMAIL_SEND_TIMEOUT_MS ?? 10_000);
const EMAIL_SEND_RETRIES = Number(process.env.EMAIL_SEND_RETRIES ?? 2);
const DOKU_ENV = String(process.env.DOKU_ENV || 'sandbox').toLowerCase();
const DOKU_CLIENT_ID = process.env.DOKU_CLIENT_ID || '';
const DOKU_SECRET_KEY = process.env.DOKU_SECRET_KEY || '';
const DOKU_BASE_URL = (process.env.DOKU_BASE_URL || (
  DOKU_ENV === 'production' ? 'https://api.doku.com' : 'https://api-sandbox.doku.com'
)).replace(/\/$/, '');
const DOKU_CHECKOUT_RETURN_URL = process.env.DOKU_CHECKOUT_RETURN_URL || `${ALLOWED_ORIGIN}/payments/doku/return`;
const DOKU_CHECKOUT_FAILED_URL = process.env.DOKU_CHECKOUT_FAILED_URL || `${ALLOWED_ORIGIN}/payments/doku/failed`;
const DOKU_NOTIFICATION_URL = process.env.DOKU_NOTIFICATION_URL || `${ALLOWED_ORIGIN}/payments/doku/webhook`;
const DOKU_CHECKOUT_AMOUNT = Number(process.env.DOKU_CHECKOUT_AMOUNT ?? 49_000);
const DOKU_CHECKOUT_DUE_MINUTES = Number(process.env.DOKU_CHECKOUT_DUE_MINUTES ?? 60);
const DOKU_SEND_TIMEOUT_MS = Number(process.env.DOKU_SEND_TIMEOUT_MS ?? 15_000);
const DOKU_SEND_RETRIES = Number(process.env.DOKU_SEND_RETRIES ?? 1);
const DOKU_SIGNATURE_TOLERANCE_MS = Number(process.env.DOKU_SIGNATURE_TOLERANCE_MS ?? 15 * 60 * 1000);

// Google Sign-In: the audience the client's idToken must be issued for.
// Defaults to the serverClientId used by the Flutter app.
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID
  || '55523615051-81vpiqk0jiamubrnjb0ss4i6irpifm2t.apps.googleusercontent.com';
const GOOGLE_VERIFY_TIMEOUT_MS = Number(process.env.GOOGLE_VERIFY_TIMEOUT_MS ?? 10_000);
const GOOGLE_VERIFY_RETRIES = Number(process.env.GOOGLE_VERIFY_RETRIES ?? 2);

const port = Number(process.env.PORT ?? 8787);
const ADMIN_TOKEN = process.env.IQROKU_ADMIN_TOKEN || 'admin-dev-token';
if (ADMIN_TOKEN === 'admin-dev-token' && process.env.NODE_ENV === 'production') {
  console.error('FATAL: IQROKU_ADMIN_TOKEN must be set in production. Refusing to start with default token.');
  process.exit(1);
}
const ADMIN_CSRF_SECRET = process.env.ADMIN_CSRF_SECRET || ADMIN_TOKEN;
const ADMIN_CSRF_MAX_AGE_MS = Number(process.env.ADMIN_CSRF_MAX_AGE_MS ?? 24 * 60 * 60 * 1000);
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
    logError('expired_auth_cleanup_failed', error);
  }
}

if (CLEANUP_EXPIRED_AUTH_INTERVAL_MS > 0) {
  setInterval(cleanupExpiredAuthData, CLEANUP_EXPIRED_AUTH_INTERVAL_MS).unref();
  setTimeout(cleanupExpiredAuthData, 10_000).unref();
}

const dokuPayments = createDokuPayments({
  config: {
    clientId: DOKU_CLIENT_ID,
    secretKey: DOKU_SECRET_KEY,
    baseUrl: DOKU_BASE_URL,
    checkoutReturnUrl: DOKU_CHECKOUT_RETURN_URL,
    checkoutFailedUrl: DOKU_CHECKOUT_FAILED_URL,
    notificationUrl: DOKU_NOTIFICATION_URL,
    checkoutAmount: DOKU_CHECKOUT_AMOUNT,
    checkoutDueMinutes: DOKU_CHECKOUT_DUE_MINUTES,
    sendTimeoutMs: DOKU_SEND_TIMEOUT_MS,
    sendRetries: DOKU_SEND_RETRIES,
    signatureToleranceMs: DOKU_SIGNATURE_TOLERANCE_MS,
  },
  db,
  fetchTextWithTimeoutAndRetry,
  httpError,
  safeStrEqual,
  escapeHtml,
  optionalString,
  truncateString,
  addMinutes,
});

const authServices = createAuthServices({
  config: {
    googleClientId: GOOGLE_CLIENT_ID,
    googleVerifyTimeoutMs: GOOGLE_VERIFY_TIMEOUT_MS,
    googleVerifyRetries: GOOGLE_VERIFY_RETRIES,
    authLinkBaseUrl: AUTH_LINK_BASE_URL,
    emailProvider: EMAIL_PROVIDER,
    resendApiKey: RESEND_API_KEY,
    emailFrom: EMAIL_FROM,
    emailReplyTo: EMAIL_REPLY_TO,
    emailSendTimeoutMs: EMAIL_SEND_TIMEOUT_MS,
    emailSendRetries: EMAIL_SEND_RETRIES,
  },
  db,
  fetchTextWithTimeoutAndRetry,
  httpError,
  addMinutes,
  escapeHtml,
  formatDateTime,
  logError,
  logEvent,
});

const {
  authenticateRequest,
  authFlowResponse,
  consumeAuthFlowToken,
  createAuthFlowToken,
  createSessionToken,
  hashPassword,
  revokeSession,
  sendAuthFlowEmail,
  storeSession,
  validatePassword,
  verifyGoogleIdToken,
  verifyPassword,
} = authServices;

const adminPanel = createAdminPanel({
  db,
  adminToken: ADMIN_TOKEN,
  secureCookieAttribute,
  safeStrEqual,
  createCsrfToken: createAdminCsrfToken,
  verifyCsrfToken: verifyAdminCsrfToken,
  enforceCsrf: enforceAdminCsrf,
  cleanString,
  requiredBody,
  normalizeEmail,
  parseBoolean,
  randomUUID,
  httpError,
  escapeHtml,
  formatDateTime,
  rupiah,
});

const learningRoutes = createLearningRoutes({
  db,
  authenticateRequest,
  enforceChildOwnership,
  enforceIqroBookAccess,
  queuePushNotification,
  logError,
  requiredBody,
  requiredQuery,
  cleanString,
  clampNumber,
  randomUUID,
  now,
  httpError,
  uploadDir: AUDIO_UPLOAD_DIR,
  maxAudioUploadBytes: MAX_AUDIO_UPLOAD_BYTES,
  allowedAudioContentTypes: ALLOWED_AUDIO_CONTENT_TYPES,
  genericAudioUploadContentTypes: GENERIC_AUDIO_UPLOAD_CONTENT_TYPES,
  allowedAudioExtensions: ALLOWED_AUDIO_EXTENSIONS,
});

const notificationRoutes = createNotificationRoutes({
  db,
  push,
  authenticateRequest,
  enforceChildOwnership,
  requiredBody,
  cleanString,
  truncateString,
  httpError,
});

const familyRoutes = createFamilyRoutes({
  db,
  authenticateRequest,
  enforceChildOwnership,
  requiredBody,
  requiredQuery,
  cleanString,
  truncateString,
  clampNumber,
  randomUUID,
  hashPassword,
  verifyPassword,
  httpError,
});

const progressRoutes = createProgressRoutes({
  db,
  authenticateRequest,
  enforceChildOwnership,
  enforceIqroBookAccess,
  requiredBody,
  requiredQuery,
  cleanString,
  clampNumber,
  httpError,
});

const billingRoutes = createBillingRoutes({
  db,
  dokuPayments,
  authenticateRequest,
  authenticateAdmin,
  requiredBody,
  randomUUID,
  now,
  addDays,
  httpError,
});

const contentRoutes = createContentRoutes({
  db,
});

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

function createAdminCsrfToken() {
  const timestamp = String(Date.now());
  const nonce = randomBytes(16).toString('base64url');
  const payload = `${timestamp}.${nonce}`;
  const signature = createHmac('sha256', ADMIN_CSRF_SECRET)
    .update(payload)
    .digest('base64url');
  return `${payload}.${signature}`;
}

function verifyAdminCsrfToken(token) {
  const parts = cleanString(token).split('.');
  if (parts.length !== 3) {
    return false;
  }
  const [timestamp, nonce, signature] = parts;
  if (!/^\d{10,}$/.test(timestamp) || !nonce || !signature) {
    return false;
  }
  const issuedAt = Number(timestamp);
  if (!Number.isFinite(issuedAt) || Date.now() - issuedAt > ADMIN_CSRF_MAX_AGE_MS) {
    return false;
  }
  if (issuedAt - Date.now() > 60_000) {
    return false;
  }
  const expected = createHmac('sha256', ADMIN_CSRF_SECRET)
    .update(`${timestamp}.${nonce}`)
    .digest('base64url');
  return safeStrEqual(signature, expected);
}

function enforceAdminCsrf(body) {
  if (!verifyAdminCsrfToken(body.csrfToken)) {
    throw httpError(403, 'admin_csrf_invalid');
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

function isAdminRestrictedPath(path) {
  return path === '/admin'
    || path.startsWith('/admin/')
    || path === '/subscriptions/activate';
}

// Behind a reverse proxy (nginx) every request's socket address is the proxy
// itself, so rate limiting on remoteAddress buckets ALL users into one counter.
// Trust only headers set by our edge proxy. Nginx must overwrite X-Real-IP and
// X-Forwarded-For with the immediate client address; client-supplied chains are
// not accepted as authority.
const TRUST_PROXY = (process.env.TRUST_PROXY ?? 'true') !== 'false';
function getClientIp(request) {
  if (TRUST_PROXY) {
    const realIp = request.headers?.['x-real-ip'];
    if (typeof realIp === 'string' && realIp.length > 0) {
      return normalizeClientIp(realIp);
    }
    const fwd = request.headers?.['x-forwarded-for'];
    if (typeof fwd === 'string' && fwd.length > 0) {
      const lastTrustedHop = fwd.split(',').map((ip) => ip.trim()).filter(Boolean).pop();
      if (lastTrustedHop) return normalizeClientIp(lastTrustedHop);
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
  const requestId = cleanString(request.headers?.['x-request-id']) || randomUUID();
  response.setHeader('x-request-id', requestId);
  let path = request.url ?? '/';
  let responseStatus = 500;
  try {
    const url = new URL(request.url ?? '/', `http://${request.headers.host}`);
    path = url.pathname;

    // Rate limit: stricter for auth endpoints
    const isAuthEndpoint = path.startsWith('/auth/');
    const isDemoLogin = path === '/auth/demo-login';
    const rateBucket = isDemoLogin ? 'demo' : isAuthEndpoint ? 'auth' : 'general';
    const rateMax = isDemoLogin ? RATE_MAX_DEMO : isAuthEndpoint ? RATE_MAX_AUTH : RATE_MAX_GENERAL;
    checkRateLimit(clientIp, rateBucket, rateMax);

    if ((request.method ?? 'GET') === 'OPTIONS') {
      sendCorsPreflight(response, request);
      responseStatus = 204;
      logRequest({ requestId, method: request.method ?? 'OPTIONS', path, status: responseStatus, ms: Date.now() - startTime, ip: clientIp });
      return;
    }

    const body = await readJson(request);
    const result = await route(request.method ?? 'GET', url, body, request);
    responseStatus = typeof result.status === 'number' ? result.status : 200;
    if (result.html) {
      sendHtml(response, responseStatus, result.html, result.headers);
      logRequest({ requestId, method: request.method ?? 'GET', path, status: responseStatus, ms: Date.now() - startTime, ip: clientIp });
      return;
    }
    if (result.filePath) {
      await sendFile(response, result.filePath, result.contentType);
      responseStatus = 200;
      logRequest({ requestId, method: request.method ?? 'GET', path, status: responseStatus, ms: Date.now() - startTime, ip: clientIp });
      return;
    }
    if (result.status === 302 && result.headers) {
      sendRedirect(response, result.status, result.headers);
      responseStatus = result.status;
      logRequest({ requestId, method: request.method ?? 'GET', path, status: responseStatus, ms: Date.now() - startTime, ip: clientIp });
      return;
    }
    sendJson(response, responseStatus, result.body ?? result);
    logRequest({ requestId, method: request.method ?? 'GET', path, status: responseStatus, ms: Date.now() - startTime, ip: clientIp });
  } catch (error) {
    responseStatus = error.statusCode ?? 500;
    sendJson(response, responseStatus, {
      error: responseStatus === 500 ? 'internal_error' : error.message,
    });
    logRequest({
      requestId,
      method: request.method ?? 'GET',
      path,
      status: responseStatus,
      ms: Date.now() - startTime,
      ip: clientIp,
      error: responseStatus === 500 ? 'internal_error' : error.message,
    });
    if (responseStatus === 500) {
      logError('request_failed', error, { requestId, method: request.method ?? 'GET', path });
    }
  }
});

server.listen(port, () => {
  logEvent('info', 'server_listening', { port });
});

// --- Graceful Shutdown ---
function gracefulShutdown(signal) {
  logEvent('info', 'server_shutdown_started', { signal });
  server.close(async () => {
    try {
      await db.closeDb();
    } catch (_) {
      // best-effort close
    }
    logEvent('info', 'server_shutdown_complete');
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

  if (isAdminRestrictedPath(path)) {
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

  if (method === 'GET' && path === '/payments/doku/return') {
    return { html: dokuPayments.renderRedirectPage({ status: 'success', url }) };
  }

  if (method === 'GET' && path === '/payments/doku/failed') {
    return { html: dokuPayments.renderRedirectPage({ status: 'failed', url }) };
  }

  if (method === 'POST' && path === DOKU_WEBHOOK_PATH) {
    return dokuPayments.handleWebhook(body, request);
  }

  if (path === '/admin' || path.startsWith('/admin/')) {
    const adminResult = await adminPanel.handle(method, path, body, request);
    if (adminResult) {
      return adminResult;
    }
  }

  const contentResult = await contentRoutes.handle(method, path);
  if (contentResult) {
    return contentResult;
  }

  const learningResult = await learningRoutes.handle(method, path, url, body, request);
  if (learningResult) {
    return learningResult;
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
    await sendAuthFlowEmail({
      type: 'email_verification',
      email,
      token: verification.token,
      expiresAt: verification.expiresAt,
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
      await sendAuthFlowEmail({
        type: 'email_verification',
        email,
        token: verification.token,
        expiresAt: verification.expiresAt,
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
      await sendAuthFlowEmail({
        type: 'password_reset',
        email,
        token: reset.token,
        expiresAt: reset.expiresAt,
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
    await db.deleteSessionsByParent(parent.id);
    await db.revokeAuthTokens(parent.id, 'password_reset');
    return { ok: true };
  }

  const familyResult = await familyRoutes.handle(method, path, url, body, request);
  if (familyResult) {
    return familyResult;
  }

  const progressResult = await progressRoutes.handle(method, path, url, body, request);
  if (progressResult) {
    return progressResult;
  }

  const billingResult = await billingRoutes.handle(method, path, body, request);
  if (billingResult) {
    return billingResult;
  }

  const notificationResult = await notificationRoutes.handle(method, path, url, body, request);
  if (notificationResult) {
    return notificationResult;
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
  request.rawBody = buffer.toString('utf8');
  const contentType = String(request.headers['content-type'] ?? '');
  const boundary = multipartBoundary(contentType);
  if (boundary) {
    return { __multipart: parseMultipart(buffer, boundary) };
  }
  const raw = request.rawBody.trim();
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

function sendCorsPreflight(response, request) {
  const requestedHeaders = cleanString(request.headers?.['access-control-request-headers']);
  response.writeHead(204, {
    'access-control-allow-origin': ALLOWED_ORIGIN,
    'access-control-allow-methods': 'GET,POST,PUT,PATCH,OPTIONS',
    'access-control-allow-headers': requestedHeaders || 'content-type,authorization',
    'access-control-max-age': '86400',
    'x-content-type-options': 'nosniff',
    'vary': 'Origin, Access-Control-Request-Headers',
  });
  response.end();
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

function optionalString(value) {
  if (value === undefined || value === null) {
    return '';
  }
  return String(value).trim();
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

async function enforceIqroBookAccess(parentId, bookId) {
  if (bookId <= 1) {
    return;
  }
  const subscription = await db.findSubscriptionByParent(parentId);
  const activeUntil = subscription?.activeUntil ? new Date(subscription.activeUntil) : null;
  const active = subscription?.active === true
    && (!activeUntil || activeUntil.getTime() > Date.now());
  if (!active) {
    throw httpError(402, 'iqroku_plus_required');
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

function queuePushNotification(notification) {
  if (!notification) {
    return;
  }
  sendPushNotification(notification).catch((error) => {
    logError('push_notification_failed', error, {
      notificationId: notification.id,
      notificationType: notification.type,
    });
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

function parseBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }
  return ['true', '1', 'yes', 'on'].includes(String(value).toLowerCase());
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
