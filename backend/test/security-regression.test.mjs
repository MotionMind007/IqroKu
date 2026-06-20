import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const serverSource = await readFile(new URL('../src/server.mjs', import.meta.url), 'utf8');
const dbSource = await readFile(new URL('../src/db.mjs', import.meta.url), 'utf8');
const nginxSource = await readFile(new URL('../../deploy/nginx-iqroku.conf', import.meta.url), 'utf8');
const deployScriptSource = await readFile(new URL('../../deploy/deploy.sh', import.meta.url), 'utf8');
const setupVpsSource = await readFile(new URL('../../deploy/setup-vps.sh', import.meta.url), 'utf8');
const envTemplateSource = await readFile(new URL('../../deploy/.env.production', import.meta.url), 'utf8');
const constraintsMigration = await readFile(
  new URL('../../deploy/migrations/002_security_constraints.sql', import.meta.url),
  'utf8',
);
const onboardingProfileMigration = await readFile(
  new URL('../../deploy/migrations/003_onboarding_profile_columns.sql', import.meta.url),
  'utf8',
);
const reviewFlowMigration = await readFile(
  new URL('../../deploy/migrations/004_review_flow_columns.sql', import.meta.url),
  'utf8',
);
const deviceTokensMigration = await readFile(
  new URL('../../deploy/migrations/005_device_tokens.sql', import.meta.url),
  'utf8',
);
const deviceTokenRolesMigration = await readFile(
  new URL('../../deploy/migrations/006_device_token_roles.sql', import.meta.url),
  'utf8',
);
const dokuPaymentsMigration = await readFile(
  new URL('../../deploy/migrations/007_doku_payments.sql', import.meta.url),
  'utf8',
);
const pushSource = await readFile(new URL('../src/push.mjs', import.meta.url), 'utf8');
const upsertDeviceTokenSource =
  dbSource.match(/export async function upsertDeviceToken[\s\S]*?export async function disableDeviceToken/)?.[0] ??
  '';
const adminMetricsSource =
  dbSource.match(/export async function getAdminMetrics[\s\S]*?\/\/ =============================================================================\r?\n\/\/ PIN MANAGEMENT/)?.[0] ??
  '';

test('demo login is explicitly gated and does not issue deterministic parent-id tokens', () => {
  assert.match(serverSource, /ENABLE_DEMO_LOGIN\s*=\s*process\.env\.ENABLE_DEMO_LOGIN === 'true'/);
  assert.match(serverSource, /if \(!ENABLE_DEMO_LOGIN\)\s*{\s*throw httpError\(404, 'not_found'\);/);
  assert.doesNotMatch(serverSource, /const token = `demo_\$\{parent\.id\}`/);
});

test('public serializers strip PIN hashes from parent and child responses', () => {
  assert.match(serverSource, /const \{ passwordHash, pinHash, \.\.\.safeParent \} = parent;/);
  assert.match(serverSource, /hasPin: Boolean\(pinHash\)/);
  assert.match(serverSource, /function publicChild\(child\)/);
  assert.match(serverSource, /const \{ pinHash, \.\.\.safeChild \} = child;/);
  assert.match(serverSource, /return children\.map\(publicChild\);/);
  assert.match(serverSource, /return \{ valid: true, child: publicChild\(child\) \};/);
});

test('audio downloads authenticate before serving stored files', () => {
  assert.match(serverSource, /if \(method === 'GET' && path\.startsWith\('\/uploads\/audio\/'\)\)/);
  assert.match(serverSource, /const authedParent = await authenticateRequest\(request\);/);
  assert.match(serverSource, /await enforceChildOwnership\(authedParent\.id, attempt\.childId\);/);
  assert.match(serverSource, /'cache-control': 'private, no-store'/);
});

test('AI and mock assessment endpoints are disabled', () => {
  assert.match(serverSource, /path === '\/assessments\/mock'[\s\S]*throw httpError\(410, 'assessment_disabled'\);/);
  assert.match(serverSource, /path === '\/assessments\/ai'[\s\S]*throw httpError\(410, 'assessment_disabled'\);/);
  assert.doesNotMatch(serverSource, /MIMO_API_KEY/);
  assert.doesNotMatch(serverSource, /assessWithMiMo/);
});

test('child dynamic routes are matched with concrete path regex helpers', () => {
  assert.match(serverSource, /function childSetPinAction\(path\)/);
  assert.match(serverSource, /\^\\\/children\\\/\(\[\^\/\]\+\)\\\/set-pin\$/);
  assert.match(serverSource, /function childScheduleAction\(path\)/);
  assert.doesNotMatch(serverSource, /path === '\/children\/:id\/set-pin'/);
  assert.doesNotMatch(serverSource, /path === '\/children\/:id\/schedule'/);
});

test('nginx proxies uploads through backend authorization instead of public alias serving', () => {
  assert.match(nginxSource, /location \/uploads\/ \{/);
  assert.match(nginxSource, /proxy_pass http:\/\/iqroku_backend;/);
  assert.doesNotMatch(nginxSource, /alias \/opt\/iqroku\/uploads\/;/);
  assert.match(deployScriptSource, /Live nginx still serves \/uploads\/ with alias/);
  assert.match(deployScriptSource, /alias\[\[:space:\]\]\+\/opt\/iqroku\/uploads\//);
});

test('auth verification and reset use one-time hashed tokens', () => {
  assert.match(serverSource, /path === '\/auth\/verify-email'/);
  assert.match(serverSource, /path === '\/auth\/password-reset\/request'/);
  assert.match(serverSource, /path === '\/auth\/password-reset\/confirm'/);
  assert.match(serverSource, /createHash\('sha256'\)\.update\(String\(token\)\)\.digest\('hex'\)/);
  assert.match(serverSource, /db\.findValidAuthToken/);
  assert.match(serverSource, /db\.markAuthTokenUsed/);
  assert.doesNotMatch(serverSource, /INSERT INTO auth_tokens[\s\S]*token\s*,/);
});

test('email provider sends auth flow tokens without production token logs', () => {
  assert.match(serverSource, /const EMAIL_PROVIDER =/);
  assert.match(serverSource, /RESEND_API_KEY/);
  assert.match(serverSource, /EMAIL_FROM/);
  assert.match(serverSource, /async function sendAuthFlowEmail/);
  assert.match(serverSource, /https:\/\/api\.resend\.com\/emails/);
  assert.match(serverSource, /'authorization': `Bearer \$\{RESEND_API_KEY\}`/);
  assert.match(serverSource, /process\.env\.NODE_ENV !== 'production'[\s\S]*payload\.token = token/);
  assert.match(envTemplateSource, /EMAIL_PROVIDER=none/);
  assert.match(envTemplateSource, /RESEND_API_KEY=/);
  assert.match(envTemplateSource, /EMAIL_FROM=/);
});

test('session tokens and auth cleanup avoid credential exposure', () => {
  assert.match(serverSource, /function createSessionToken\(\)/);
  assert.match(serverSource, /session_\$\{randomBytes\(32\)\.toString\('base64url'\)\}/);
  assert.doesNotMatch(serverSource, /session_\$\{parentId\}/);
  assert.doesNotMatch(serverSource, /createSessionToken\(parent\.id\)/);
  assert.match(serverSource, /async function cleanupExpiredAuthData\(\)/);
  assert.match(serverSource, /await db\.cleanupExpiredSessions\(\)/);
  assert.match(serverSource, /await db\.cleanupExpiredAuthTokens\(\)/);
  assert.match(setupVpsSource, /DELETE FROM sessions WHERE expires_at < NOW\(\)/);
  assert.match(setupVpsSource, /DELETE FROM auth_tokens WHERE expires_at < NOW\(\) - INTERVAL '7 days'/);
});

test('admin metrics use bounded SQL aggregation instead of loading full tables', () => {
  assert.match(adminMetricsSource, /COUNT\(\*\)::int AS parents/);
  assert.match(adminMetricsSource, /LIMIT \$1/);
  assert.match(adminMetricsSource, /parentListLimit = 100/);
  assert.doesNotMatch(adminMetricsSource, /getAllParents\(\)/);
  assert.doesNotMatch(adminMetricsSource, /getAllChildren\(\)/);
  assert.doesNotMatch(adminMetricsSource, /getAllSubscriptions\(\)/);
  assert.doesNotMatch(adminMetricsSource, /getAllProgress\(\)/);
  assert.doesNotMatch(adminMetricsSource, /attemptListLimit/);
  assert.doesNotMatch(adminMetricsSource, /ORDER BY a\.created_at DESC/);
});

test('admin routes support optional backend IP allowlist', () => {
  assert.match(serverSource, /const ADMIN_ALLOWED_IPS = new Set/);
  assert.match(serverSource, /function enforceAdminIpAllowlist\(request\)/);
  assert.match(serverSource, /throw httpError\(403, 'admin_ip_not_allowed'\)/);
  assert.match(serverSource, /if \(path === '\/admin' \|\| path\.startsWith\('\/admin\/'\)\)/);
  assert.match(serverSource, /enforceAdminIpAllowlist\(request\)/);
  assert.match(serverSource, /function normalizeClientIp\(value\)/);
  assert.match(envTemplateSource, /ADMIN_ALLOWED_IPS=/);
});

test('admin parent deletion requires admin auth and explicit email confirmation', () => {
  assert.match(serverSource, /function adminParentAction\(path\)/);
  assert.match(serverSource, /\^\\\/admin\\\/parents\\\/\(\[\^\/\]\+\)\\\/\(delete\)\$/);
  assert.match(serverSource, /authenticateAdmin\(request\);[\s\S]*const parent = await db\.findParentById\(parentAction\.id\)/);
  assert.match(serverSource, /const confirmEmail = normalizeEmail\(requiredBody\(body, 'confirmEmail'\)\)/);
  assert.match(serverSource, /confirmEmail !== parent\.email/);
  assert.match(serverSource, /await db\.deleteParent\(parent\.id\)/);
  assert.match(serverSource, /Ketik email untuk hapus/);
  assert.match(dbSource, /export async function deleteParent/);
  assert.match(dbSource, /DELETE FROM notifications/);
  assert.match(dbSource, /DELETE FROM parents WHERE id = \$1 RETURNING \*/);
});

test('DOKU payment foundation verifies webhooks and keeps premium server-side', () => {
  assert.match(serverSource, /const DOKU_CLIENT_ID =/);
  assert.match(serverSource, /const DOKU_SECRET_KEY =/);
  assert.match(serverSource, /const DOKU_CHECKOUT_PATH = '\/checkout\/v1\/payment'/);
  assert.match(serverSource, /path === '\/payments\/doku\/checkout'/);
  assert.match(serverSource, /const authedParent = await authenticateRequest\(request\);[\s\S]*return createDokuCheckout\(authedParent\);/);
  assert.match(serverSource, /path === '\/subscriptions\/status'/);
  assert.match(serverSource, /subscription: publicSubscription\(subscription\)/);
  assert.match(serverSource, /path === '\/payments\/doku\/return'/);
  assert.match(serverSource, /path === '\/payments\/doku\/failed'/);
  assert.match(serverSource, /function renderDokuRedirectPage/);
  assert.match(serverSource, /path === DOKU_WEBHOOK_PATH/);
  assert.match(serverSource, /function verifyDokuSignature\(request\)/);
  assert.match(serverSource, /createHmac\('sha256', DOKU_SECRET_KEY\)/);
  assert.match(serverSource, /Client-Id:\$\{DOKU_CLIENT_ID\}/);
  assert.match(serverSource, /request\.rawBody \?\? ''/);
  assert.match(serverSource, /await db\.applyPaymentNotification/);
  assert.match(dbSource, /export async function applyPaymentNotification/);
  assert.match(dbSource, /ON CONFLICT \(provider, request_id\) DO NOTHING/);
  assert.match(dbSource, /previousStatus !== 'paid'/);
  assert.match(envTemplateSource, /DOKU_CLIENT_ID=/);
  assert.match(envTemplateSource, /DOKU_SECRET_KEY=/);
  assert.match(envTemplateSource, /DOKU_NOTIFICATION_URL=https:\/\/iqroku\.motionmind\.store\/payments\/doku\/webhook/);
});

test('review decisions are applied through one database transaction', () => {
  assert.match(dbSource, /async function withTransaction\(work\)/);
  assert.match(dbSource, /await client\.query\('BEGIN'\)/);
  assert.match(dbSource, /await client\.query\('COMMIT'\)/);
  assert.match(dbSource, /await client\.query\('ROLLBACK'\)/);
  assert.match(dbSource, /export async function approveReview/);
  assert.match(dbSource, /export async function repeatReview/);
  assert.match(serverSource, /await db\.approveReview\(\{/);
  assert.match(serverSource, /await db\.repeatReview\(\{/);
});

test('audio upload handling enforces size, type, extension, and content sniffing', () => {
  assert.match(serverSource, /MAX_AUDIO_UPLOAD_BYTES/);
  assert.match(serverSource, /const ALLOWED_AUDIO_CONTENT_TYPES = new Set/);
  assert.match(serverSource, /const GENERIC_AUDIO_UPLOAD_CONTENT_TYPES = new Set/);
  assert.match(serverSource, /'application\/octet-stream'/);
  assert.match(serverSource, /const ALLOWED_AUDIO_EXTENSIONS = new Set/);
  assert.match(serverSource, /validateAudioUpload\(\{ originalFileName, contentType, content \}\);/);
  assert.match(serverSource, /throw httpError\(413, 'audio_file_too_large'\)/);
  assert.match(serverSource, /throw httpError\(415, 'unsupported_audio_type'\)/);
  assert.match(serverSource, /throw httpError\(415, 'unsupported_audio_extension'\)/);
  assert.match(serverSource, /throw httpError\(415, 'invalid_audio_file'\)/);
  assert.match(serverSource, /GENERIC_AUDIO_UPLOAD_CONTENT_TYPES\.has\(normalizedType\)/);
  assert.match(serverSource, /function looksLikeAudio\(content\)/);
});

test('basic HTTP response hardening is enabled for JSON, files, and admin cookies', () => {
  assert.match(serverSource, /'x-content-type-options': 'nosniff'/);
  assert.match(serverSource, /'vary': 'Origin'/);
  assert.match(serverSource, /function secureCookieAttribute\(\)/);
  assert.match(serverSource, /process\.env\.NODE_ENV === 'production' \? '; Secure' : ''/);
  assert.match(serverSource, /SameSite=Strict; Max-Age=86400\$\{secureCookieAttribute\(\)\}/);
  assert.match(serverSource, /replaceAll\('`', '&#96;'\)/);
});

test('database constraints cover persisted status and reviewer references', () => {
  assert.match(constraintsMigration, /progress_status_check/);
  assert.match(constraintsMigration, /progress_review_status_check/);
  assert.match(constraintsMigration, /attempts_assessment_status_check/);
  assert.match(constraintsMigration, /attempts_review_status_check/);
  assert.match(constraintsMigration, /attempts_status_check/);
  assert.match(constraintsMigration, /attempts_reviewed_by_fkey/);
  assert.match(constraintsMigration, /progress_reviewed_by_fkey/);
  assert.match(constraintsMigration, /auth_tokens_purpose_check/);
  assert.match(constraintsMigration, /notifications_user_type_check/);
});

test('device token routes require auth and validate child ownership', () => {
  assert.match(serverSource, /path === '\/devices\/register'/);
  assert.match(serverSource, /path === '\/devices\/unregister'/);
  assert.match(serverSource, /const authedParent = await authenticateRequest\(request\);/);
  assert.match(serverSource, /normalizeDeviceToken\(requiredBody\(body, 'token'\)\)/);
  assert.match(serverSource, /await enforceChildOwnership\(authedParent\.id, childId\);/);
});

test('push sender uses FCM HTTP v1 without firebase-admin dependency', () => {
  assert.match(pushSource, /https:\/\/fcm\.googleapis\.com\/v1\/projects\/\$\{projectId\}\/messages:send/);
  assert.match(pushSource, /createSign\('RSA-SHA256'\)/);
  assert.match(pushSource, /FIREBASE_SERVICE_ACCOUNT_JSON/);
  assert.doesNotMatch(pushSource, /firebase-admin/);
});

test('migrations backfill onboarding profile columns used by runtime code', () => {
  assert.match(onboardingProfileMigration, /ALTER TABLE parents[\s\S]*ADD COLUMN IF NOT EXISTS pin_hash TEXT/);
  assert.match(onboardingProfileMigration, /ALTER TABLE children[\s\S]*ADD COLUMN IF NOT EXISTS pin_hash TEXT/);
  assert.match(onboardingProfileMigration, /ADD COLUMN IF NOT EXISTS study_start_time TIME/);
  assert.match(onboardingProfileMigration, /ADD COLUMN IF NOT EXISTS study_end_time TIME/);
  assert.match(onboardingProfileMigration, /ADD COLUMN IF NOT EXISTS study_days INTEGER\[\]/);
  assert.match(onboardingProfileMigration, /ALTER TABLE progress[\s\S]*ADD COLUMN IF NOT EXISTS reviewed_by UUID/);
});

test('migrations backfill review flow columns used by runtime code', () => {
  assert.match(reviewFlowMigration, /ALTER TABLE progress[\s\S]*ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ/);
  assert.match(reviewFlowMigration, /ADD COLUMN IF NOT EXISTS review_status VARCHAR\(20\)/);
  assert.match(reviewFlowMigration, /ALTER TABLE attempts[\s\S]*ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ/);
  assert.match(reviewFlowMigration, /ADD COLUMN IF NOT EXISTS assessment_status VARCHAR\(30\)/);
  assert.match(reviewFlowMigration, /ADD COLUMN IF NOT EXISTS audio_file_name VARCHAR\(200\)/);
  assert.match(reviewFlowMigration, /ALTER TABLE children[\s\S]*ADD COLUMN IF NOT EXISTS repeat_from_page INTEGER/);
  assert.match(reviewFlowMigration, /ADD COLUMN IF NOT EXISTS repeat_from_book INTEGER/);
});

test('migration creates device token storage for FCM push notifications', () => {
  assert.match(deviceTokensMigration, /CREATE TABLE IF NOT EXISTS device_tokens/);
  assert.match(deviceTokensMigration, /token TEXT NOT NULL/);
  assert.match(deviceTokensMigration, /REFERENCES parents\(id\) ON DELETE CASCADE/);
  assert.match(deviceTokensMigration, /REFERENCES children\(id\) ON DELETE CASCADE/);
  assert.match(deviceTokensMigration, /user_type IN \('parent', 'child'\)/);
  assert.match(deviceTokensMigration, /idx_device_tokens_user/);
});

test('migration allows one FCM token to be registered for parent and child roles', () => {
  assert.match(deviceTokenRolesMigration, /DROP CONSTRAINT IF EXISTS device_tokens_token_key/);
  assert.match(deviceTokenRolesMigration, /idx_device_tokens_parent_token/);
  assert.match(deviceTokenRolesMigration, /idx_device_tokens_child_token/);
  assert.match(upsertDeviceTokenSource, /SELECT id[\s\S]*FROM device_tokens[\s\S]*WHERE token = \$1/);
  assert.doesNotMatch(upsertDeviceTokenSource, /ON CONFLICT \(token\)/);
});

test('migration creates idempotent DOKU payment order and event storage', () => {
  assert.match(dokuPaymentsMigration, /CREATE TABLE IF NOT EXISTS payment_orders/);
  assert.match(dokuPaymentsMigration, /invoice_number VARCHAR\(120\) NOT NULL UNIQUE/);
  assert.match(dokuPaymentsMigration, /status IN \('pending', 'paid', 'failed', 'expired', 'cancelled'\)/);
  assert.match(dokuPaymentsMigration, /CREATE TABLE IF NOT EXISTS payment_events/);
  assert.match(dokuPaymentsMigration, /UNIQUE \(provider, request_id\)/);
  assert.match(dokuPaymentsMigration, /signature_valid BOOLEAN NOT NULL DEFAULT FALSE/);
  assert.match(dokuPaymentsMigration, /REFERENCES parents\(id\) ON DELETE CASCADE/);
});
