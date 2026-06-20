import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const serverSource = await readFile(new URL('../src/server.mjs', import.meta.url), 'utf8');
const dbSource = await readFile(new URL('../src/db.mjs', import.meta.url), 'utf8');
const dbMappersSource = await readFile(new URL('../src/db-mappers.mjs', import.meta.url), 'utf8');
const nginxSource = await readFile(new URL('../../deploy/nginx-iqroku.conf', import.meta.url), 'utf8');
const deployScriptSource = await readFile(new URL('../../deploy/deploy.sh', import.meta.url), 'utf8');
const restoreBackupSource = await readFile(new URL('../../deploy/restore-backup.sh', import.meta.url), 'utf8');
const backupSource = await readFile(new URL('../../deploy/backup.sh', import.meta.url), 'utf8');
const dockerComposeSource = await readFile(new URL('../../docker-compose.yml', import.meta.url), 'utf8');
const opsCheckSource = await readFile(new URL('../../deploy/ops-check.sh', import.meta.url), 'utf8');
const weeklyRestoreDrillSource = await readFile(new URL('../../deploy/weekly-restore-drill.sh', import.meta.url), 'utf8');
const setupVpsSource = await readFile(new URL('../../deploy/setup-vps.sh', import.meta.url), 'utf8');
const smokeTestSource = await readFile(new URL('../../deploy/smoke-test.sh', import.meta.url), 'utf8');
const envTemplateSource = await readFile(new URL('../../deploy/env.production.example', import.meta.url), 'utf8');
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
const performanceIndexesMigration = await readFile(
  new URL('../../deploy/migrations/008_performance_indexes.sql', import.meta.url),
  'utf8',
);
const securityHardeningMigration = await readFile(
  new URL('../../deploy/migrations/009_security_hardening.sql', import.meta.url),
  'utf8',
);
const androidManifestSource = await readFile(
  new URL('../../iqroku_app/android/app/src/main/AndroidManifest.xml', import.meta.url),
  'utf8',
);
const androidDebugManifestSource = await readFile(
  new URL('../../iqroku_app/android/app/src/debug/AndroidManifest.xml', import.meta.url),
  'utf8',
);
const androidBuildGradleSource = await readFile(
  new URL('../../iqroku_app/android/app/build.gradle.kts', import.meta.url),
  'utf8',
);
const flutterAuthApiSource = await readFile(
  new URL('../../iqroku_app/lib/data/auth_api_service.dart', import.meta.url),
  'utf8',
);
const flutterLocalStorageSource = await readFile(
  new URL('../../iqroku_app/lib/data/local_app_storage.dart', import.meta.url),
  'utf8',
);
const flutterAppStateSource = await readFile(
  new URL('../../iqroku_app/lib/app/app_state.dart', import.meta.url),
  'utf8',
);
const flutterVoiceRecordingSource = await readFile(
  new URL('../../iqroku_app/lib/data/voice_recording_service.dart', import.meta.url),
  'utf8',
);
const flutterPushSource = await readFile(
  new URL('../../iqroku_app/lib/data/push_notification_service.dart', import.meta.url),
  'utf8',
);
const pushSource = await readFile(new URL('../src/push.mjs', import.meta.url), 'utf8');
const dokuSource = await readFile(new URL('../src/payments/doku.mjs', import.meta.url), 'utf8');
const externalFetchSource = await readFile(new URL('../src/external-fetch.mjs', import.meta.url), 'utf8');
const observabilitySource = await readFile(new URL('../src/observability.mjs', import.meta.url), 'utf8');
const authSource = await readFile(new URL('../src/auth.mjs', import.meta.url), 'utf8');
const adminSource = await readFile(new URL('../src/admin.mjs', import.meta.url), 'utf8');
const billingSource = await readFile(new URL('../src/billing.mjs', import.meta.url), 'utf8');
const contentSource = await readFile(new URL('../src/content.mjs', import.meta.url), 'utf8');
const familySource = await readFile(new URL('../src/family.mjs', import.meta.url), 'utf8');
const learningSource = await readFile(new URL('../src/learning.mjs', import.meta.url), 'utf8');
const notificationSource = await readFile(new URL('../src/notifications.mjs', import.meta.url), 'utf8');
const progressSource = await readFile(new URL('../src/progress.mjs', import.meta.url), 'utf8');
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
  assert.match(dbSource, /from '\.\/db-mappers\.mjs'/);
  assert.match(dbMappersSource, /export function rowToParent\(row\)/);
  assert.match(dbMappersSource, /passwordHash: row\.password_hash \?\? undefined/);
  assert.match(dbMappersSource, /pinHash: row\.pin_hash \?\? undefined/);
  assert.match(familySource, /function publicChild\(child\)/);
  assert.match(familySource, /const \{ pinHash, \.\.\.safeChild \} = child;/);
  assert.match(familySource, /return children\.map\(publicChild\);/);
  assert.match(familySource, /return \{ valid: true, child: publicChild\(child\) \};/);
});

test('production env template is explicit example file, not tracked as a real env file', () => {
  assert.match(envTemplateSource, /CHANGE_THIS_PASSWORD/);
  assert.match(envTemplateSource, /DOKU_SECRET_KEY=/);
});

test('database row mappers are isolated from query code', () => {
  assert.match(dbMappersSource, /export function rowToAttempt\(row\)/);
  assert.match(dbMappersSource, /audioUploadedAt: row\.audio_uploaded_at\?\.toISOString\(\)/);
  assert.match(dbMappersSource, /export function rowToPaymentOrder\(row\)/);
  assert.match(dbMappersSource, /checkoutUrl: row\.checkout_url \?\? undefined/);
  assert.match(dbMappersSource, /export function rowToDeviceToken\(row\)/);
  assert.doesNotMatch(dbSource, /function rowToAttempt\(row\)/);
  assert.doesNotMatch(dbSource, /function rowToPaymentOrder\(row\)/);
  assert.doesNotMatch(dbSource, /function rowToDeviceToken\(row\)/);
});

test('audio downloads authenticate before serving stored files', () => {
  assert.match(serverSource, /createLearningRoutes\(\{/);
  assert.match(serverSource, /learningRoutes\.handle\(method, path, url, body, request\)/);
  assert.match(learningSource, /if \(method === 'GET' && path\.startsWith\('\/uploads\/audio\/'\)\)/);
  assert.match(learningSource, /const authedParent = await authenticateRequest\(request\);/);
  assert.match(learningSource, /await enforceChildOwnership\(authedParent\.id, attempt\.childId\);/);
  assert.match(serverSource, /'cache-control': 'private, no-store'/);
});

test('AI and mock assessment endpoints are disabled', () => {
  assert.match(serverSource, /createProgressRoutes\(\{/);
  assert.match(serverSource, /progressRoutes\.handle\(method, path, url, body, request\)/);
  assert.match(progressSource, /path === '\/assessments\/mock'[\s\S]*throw httpError\(410, 'assessment_disabled'\);/);
  assert.match(progressSource, /path === '\/assessments\/ai'[\s\S]*throw httpError\(410, 'assessment_disabled'\);/);
  assert.doesNotMatch(serverSource, /MIMO_API_KEY/);
  assert.doesNotMatch(serverSource, /assessWithMiMo/);
});

test('child dynamic routes are matched with concrete path regex helpers', () => {
  assert.match(serverSource, /createFamilyRoutes\(\{/);
  assert.match(serverSource, /familyRoutes\.handle\(method, path, url, body, request\)/);
  assert.match(familySource, /function childSetPinAction\(path\)/);
  assert.match(familySource, /\^\\\/children\\\/\(\[\^\/\]\+\)\\\/set-pin\$/);
  assert.match(familySource, /function childScheduleAction\(path\)/);
  assert.doesNotMatch(serverSource, /path === '\/children\/:id\/set-pin'/);
  assert.doesNotMatch(serverSource, /path === '\/children\/:id\/schedule'/);
});

test('public content routes serialize daily prayers through a dedicated module', () => {
  assert.match(serverSource, /createContentRoutes\(\{/);
  assert.match(serverSource, /contentRoutes\.handle\(method, path\)/);
  assert.match(contentSource, /path === '\/daily-prayers'/);
  assert.match(contentSource, /db\.getActivePrayers\(\)/);
  assert.match(contentSource, /sortOrder: Number\(prayer\.sortOrder \?\? 0\)/);
});

test('progress routes require child ownership and validate statuses', () => {
  assert.match(progressSource, /path === '\/progress'/);
  assert.match(progressSource, /await enforceChildOwnership\(authedParent\.id, childId\);/);
  assert.match(progressSource, /await enforceIqroBookAccess\(authedParent\.id, bookId\);/);
  assert.match(progressSource, /const validStatuses = \['notStarted', 'learning', 'fluent', 'review'\]/);
  assert.match(progressSource, /throw httpError\(400, 'invalid_status'\)/);
  assert.match(progressSource, /db\.upsertProgress\(\{ childId, bookId, pageNumber, status \}\)/);
});

test('premium Iqro books are enforced server-side for recording and progress writes', () => {
  assert.match(serverSource, /function enforceIqroBookAccess\(parentId, bookId\)/);
  assert.match(serverSource, /if \(bookId <= 1\)/);
  assert.match(serverSource, /db\.findSubscriptionByParent\(parentId\)/);
  assert.match(serverSource, /throw httpError\(402, 'iqroku_plus_required'\)/);
  assert.match(learningSource, /await enforceIqroBookAccess\(authedParent\.id, bookId\);/);
  assert.match(progressSource, /await enforceIqroBookAccess\(authedParent\.id, bookId\);/);
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
  assert.match(serverSource, /createAuthServices\(\{/);
  assert.match(authSource, /createHash\('sha256'\)\.update\(String\(token\)\)\.digest\('hex'\)/);
  assert.match(authSource, /db\.findValidAuthToken/);
  assert.match(authSource, /db\.markAuthTokenUsed/);
  assert.doesNotMatch(authSource, /INSERT INTO auth_tokens[\s\S]*token\s*,/);
});

test('email provider sends auth flow tokens without production token logs', () => {
  assert.match(serverSource, /const EMAIL_PROVIDER =/);
  assert.match(serverSource, /RESEND_API_KEY/);
  assert.match(serverSource, /EMAIL_FROM/);
  assert.match(serverSource, /EMAIL_SEND_RETRIES/);
  assert.match(authSource, /async function sendAuthFlowEmail/);
  assert.match(authSource, /https:\/\/api\.resend\.com\/emails/);
  assert.match(authSource, /'authorization': `Bearer \$\{config\.resendApiKey\}`/);
  assert.match(authSource, /label: 'resend_email'/);
  assert.match(authSource, /process\.env\.NODE_ENV !== 'production'[\s\S]*payload\.token = token/);
  assert.match(envTemplateSource, /EMAIL_PROVIDER=none/);
  assert.match(envTemplateSource, /RESEND_API_KEY=/);
  assert.match(envTemplateSource, /EMAIL_FROM=/);
  assert.match(envTemplateSource, /EMAIL_SEND_RETRIES=2/);
});

test('session tokens and auth cleanup avoid credential exposure', () => {
  assert.match(authSource, /function createSessionToken\(\)/);
  assert.match(authSource, /session_\$\{randomBytes\(32\)\.toString\('base64url'\)\}/);
  assert.doesNotMatch(serverSource, /session_\$\{parentId\}/);
  assert.doesNotMatch(serverSource, /createSessionToken\(parent\.id\)/);
  assert.match(dbSource, /function hashSessionToken\(token\)/);
  assert.match(dbSource, /createHash\('sha256'\)\.update\(String\(token\)\)\.digest\('hex'\)/);
  assert.match(dbSource, /INSERT INTO sessions \(token_hash, parent_id\)/);
  assert.match(dbSource, /WHERE token_hash = \$1 AND expires_at > NOW\(\)/);
  assert.match(dbSource, /export async function deleteSessionsByParent\(parentId\)/);
  assert.match(serverSource, /await db\.deleteSessionsByParent\(parent\.id\)/);
  assert.doesNotMatch(dbSource, /INSERT INTO sessions \(token, parent_id\)/);
  assert.match(serverSource, /async function cleanupExpiredAuthData\(\)/);
  assert.match(serverSource, /await db\.cleanupExpiredSessions\(\)/);
  assert.match(serverSource, /await db\.cleanupExpiredAuthTokens\(\)/);
  assert.match(setupVpsSource, /DELETE FROM sessions WHERE expires_at < NOW\(\)/);
  assert.match(setupVpsSource, /DELETE FROM auth_tokens WHERE expires_at < NOW\(\) - INTERVAL '7 days'/);
});

test('operations checks cover health, backups, disk, permissions, and upload auth', () => {
  assert.match(opsCheckSource, /BASE_URL="\$\{BASE_URL:-http:\/\/localhost:8787\}"/);
  assert.match(opsCheckSource, /BACKUP_MAX_AGE_HOURS="\$\{BACKUP_MAX_AGE_HOURS:-30\}"/);
  assert.match(opsCheckSource, /UPLOADS_WARN_MB="\$\{UPLOADS_WARN_MB:-5120\}"/);
  assert.match(opsCheckSource, /BACKUPS_WARN_MB="\$\{BACKUPS_WARN_MB:-10240\}"/);
  assert.match(opsCheckSource, /AUDIO_FILE_WARN_COUNT="\$\{AUDIO_FILE_WARN_COUNT:-10000\}"/);
  assert.match(opsCheckSource, /pm2 pid iqroku/);
  assert.match(opsCheckSource, /npm run migrate:status --prefix "\$\{APP_DIR\}\/backend"/);
  assert.match(opsCheckSource, /gzip -t "\$LATEST_DB_BACKUP"/);
  assert.match(opsCheckSource, /DISK_WARN_PERCENT="\$\{DISK_WARN_PERCENT:-85\}"/);
  assert.match(opsCheckSource, /section 6 "IqroKu storage footprint"/);
  assert.match(opsCheckSource, /audio files: \$\{AUDIO_COUNT\}/);
  assert.match(opsCheckSource, /FIREBASE_SERVICE_ACCOUNT_PATH/);
  assert.match(opsCheckSource, /live nginx serves \/uploads\/ with alias/);
  assert.match(opsCheckSource, /sudo -n nginx -T/);
  assert.match(opsCheckSource, /NOPASSWD: \/usr\/sbin\/nginx -T/);
  assert.match(deployScriptSource, /OPS_BASE_URL="\$\{OPS_BASE_URL:-https:\/\/iqroku\.motionmind\.store\}"/);
  assert.match(deployScriptSource, /cp "\$APP_DIR\/deploy\/ops-check\.sh" "\$APP_DIR\/ops-check\.sh"/);
  assert.match(setupVpsSource, /ops-check\.sh/);
  assert.match(setupVpsSource, /\/var\/log\/iqroku\/ops-check\.log/);
});

test('weekly restore drill uses latest backup and is installed by setup and deploy', () => {
  assert.match(weeklyRestoreDrillSource, /LATEST_DB_BACKUP="\$\(ls -1t "\$\{BACKUP_DIR\}"\/iqroku_\*\.sql\.gz/);
  assert.match(weeklyRestoreDrillSource, /LATEST_UPLOADS_BACKUP="\$\(ls -1t "\$\{BACKUP_DIR\}"\/uploads_\*\.tar\.gz/);
  assert.match(weeklyRestoreDrillSource, /REQUIRE_UPLOADS_BACKUP="\$\{REQUIRE_UPLOADS_BACKUP:-false\}"/);
  assert.match(weeklyRestoreDrillSource, /"\$RESTORE_DRILL_SCRIPT" "\$LATEST_DB_BACKUP" "\$LATEST_UPLOADS_BACKUP"/);
  assert.match(setupVpsSource, /weekly-restore-drill\.sh/);
  assert.match(setupVpsSource, /\/var\/log\/iqroku\/restore-drill\.log/);
  assert.match(deployScriptSource, /weekly-restore-drill\.sh/);
  assert.match(deployScriptSource, /\/var\/log\/iqroku\/restore-drill\.log/);
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
  assert.match(serverSource, /function isAdminRestrictedPath\(path\)/);
  assert.match(serverSource, /path === '\/subscriptions\/activate'/);
  assert.match(serverSource, /if \(isAdminRestrictedPath\(path\)\)/);
  assert.match(serverSource, /enforceAdminIpAllowlist\(request\)/);
  assert.match(serverSource, /request\.headers\?\.\['x-real-ip'\]/);
  assert.match(serverSource, /const lastTrustedHop = fwd\.split\(','\)/);
  assert.match(serverSource, /\.filter\(Boolean\)\.pop\(\)/);
  assert.match(nginxSource, /proxy_set_header X-Forwarded-For \$remote_addr;/);
  assert.doesNotMatch(nginxSource, /\$proxy_add_x_forwarded_for/);
  assert.match(serverSource, /function normalizeClientIp\(value\)/);
  assert.match(envTemplateSource, /ADMIN_ALLOWED_IPS=/);
});

test('restore, backup, and local database defaults are hardened', () => {
  assert.match(restoreBackupSource, /psql -v ON_ERROR_STOP=1 -d "\$DB_NAME"/);
  assert.match(restoreBackupSource, /tar -tzf "\$UPLOADS_FILE" >\/dev\/null/);
  assert.match(restoreBackupSource, /Uploads archive contains unsafe paths\./);
  assert.match(restoreBackupSource, /tar --no-same-owner -xzf "\$UPLOADS_FILE"/);
  assert.match(backupSource, /chmod 700 "\$BACKUP_DIR"/);
  assert.match(backupSource, /chmod 600 "\$BACKUP_FILE"/);
  assert.match(dockerComposeSource, /POSTGRES_PASSWORD: \$\{POSTGRES_PASSWORD:\?set POSTGRES_PASSWORD in your local \.env\}/);
  assert.match(dockerComposeSource, /"127\.0\.0\.1:5433:5432"/);
});

test('production deploy rejects unsafe production defaults', () => {
  assert.match(deployScriptSource, /STRICT_PRODUCTION_READINESS:-true/);
  assert.match(deployScriptSource, /CHANGE_THIS\|admin-dev-token\|iqroku123/);
  assert.match(deployScriptSource, /REQUIRE_EMAIL_VERIFICATION must be true/);
  assert.match(deployScriptSource, /EMAIL_PROVIDER must be configured/);
  assert.match(deployScriptSource, /DOKU_ENV=sandbox is not allowed/);
  assert.doesNotMatch(setupVpsSource, /Admin:\s+https:\/\/\$\{DOMAIN\}\/admin\?token=/);
  assert.doesNotMatch(setupVpsSource, /DB Password:\s+\$\{DB_PASS\}/);
  assert.doesNotMatch(setupVpsSource, /Admin Token:\s+\$\{ADMIN_TOKEN\}/);
});

test('admin forms include CSRF tokens and admin mutations verify them', () => {
  assert.match(serverSource, /createAdminPanel\(\{/);
  assert.match(serverSource, /const ADMIN_CSRF_SECRET =/);
  assert.match(serverSource, /function createAdminCsrfToken\(\)/);
  assert.match(serverSource, /function verifyAdminCsrfToken\(token\)/);
  assert.match(serverSource, /function enforceAdminCsrf\(body\)/);
  assert.match(serverSource, /throw httpError\(403, 'admin_csrf_invalid'\)/);
  assert.match(adminSource, /verifyCsrfToken\(body\.csrfToken\)/);
  assert.match(adminSource, /enforceCsrf\(body\);[\s\S]*const fields = prayerFromBody\(body\)/);
  assert.match(adminSource, /enforceCsrf\(body\);[\s\S]*const prayer = await db\.findPrayerById/);
  assert.match(adminSource, /enforceCsrf\(body\);[\s\S]*const parent = await db\.findParentById/);
  assert.match(adminSource, /name="csrfToken" type="hidden"/);
  assert.match(envTemplateSource, /ADMIN_CSRF_SECRET=/);
});

test('admin parent deletion requires admin auth and explicit email confirmation', () => {
  assert.match(adminSource, /function adminParentAction\(path\)/);
  assert.match(adminSource, /\^\\\/admin\\\/parents\\\/\(\[\^\/\]\+\)\\\/\(delete\)\$/);
  assert.match(adminSource, /authenticateAdmin\(request\);[\s\S]*const parent = await db\.findParentById\(parentAction\.id\)/);
  assert.match(adminSource, /const confirmEmail = normalizeEmail\(requiredBody\(body, 'confirmEmail'\)\)/);
  assert.match(adminSource, /confirmEmail !== parent\.email/);
  assert.match(adminSource, /await db\.deleteParent\(parent\.id\)/);
  assert.match(adminSource, /Ketik email untuk hapus/);
  assert.match(dbSource, /export async function deleteParent/);
  assert.match(dbSource, /DELETE FROM notifications/);
  assert.match(dbSource, /DELETE FROM parents WHERE id = \$1 RETURNING \*/);
});

test('DOKU payment foundation verifies webhooks and keeps premium server-side', () => {
  assert.match(serverSource, /const DOKU_CLIENT_ID =/);
  assert.match(serverSource, /const DOKU_SECRET_KEY =/);
  assert.match(serverSource, /const DOKU_SEND_RETRIES =/);
  assert.match(serverSource, /createDokuPayments\(\{/);
  assert.match(serverSource, /createBillingRoutes\(\{/);
  assert.match(serverSource, /billingRoutes\.handle\(method, path, body, request\)/);
  assert.match(dokuSource, /export const DOKU_CHECKOUT_PATH = '\/checkout\/v1\/payment'/);
  assert.match(billingSource, /path === '\/payments\/doku\/checkout'/);
  assert.match(billingSource, /const authedParent = await authenticateRequest\(request\);[\s\S]*return dokuPayments\.createCheckout\(authedParent\);/);
  assert.match(billingSource, /path === '\/subscriptions\/status'/);
  assert.match(billingSource, /subscription: publicSubscription\(subscription\)/);
  assert.match(billingSource, /paymentStatusAction\(path\)/);
  assert.match(billingSource, /order\.parentId !== authedParent\.id[\s\S]*throw httpError\(403, 'access_denied'\)/);
  assert.match(serverSource, /path === '\/payments\/doku\/return'/);
  assert.match(serverSource, /path === '\/payments\/doku\/failed'/);
  assert.match(serverSource, /dokuPayments\.renderRedirectPage/);
  assert.match(serverSource, /path === DOKU_WEBHOOK_PATH/);
  assert.match(serverSource, /dokuPayments\.handleWebhook\(body, request\)/);
  assert.match(dokuSource, /function verifySignature\(request\)/);
  assert.match(dokuSource, /!safeStrEqual\(clientId, config\.clientId\)/);
  assert.match(dokuSource, /createHmac\('sha256', config\.secretKey\)/);
  assert.match(dokuSource, /Client-Id:\$\{config\.clientId\}/);
  assert.match(dokuSource, /typeof request\.rawBody !== 'string'/);
  assert.match(dokuSource, /missing_doku_raw_body/);
  assert.doesNotMatch(dokuSource, /request\.rawBody \?\? ''/);
  assert.match(dokuSource, /await db\.applyPaymentNotification/);
  assert.match(dbSource, /export async function applyPaymentNotification/);
  assert.match(dbSource, /ON CONFLICT \(provider, request_id\) DO NOTHING/);
  assert.match(dbSource, /previousStatus !== 'paid'/);
  assert.match(envTemplateSource, /DOKU_CLIENT_ID=/);
  assert.match(envTemplateSource, /DOKU_SECRET_KEY=/);
  assert.match(envTemplateSource, /DOKU_SEND_RETRIES=1/);
  assert.match(envTemplateSource, /DOKU_NOTIFICATION_URL=https:\/\/iqroku\.motionmind\.store\/payments\/doku\/webhook/);
});

test('backend emits request ids and uses timeout/retry wrappers for external calls', () => {
  assert.match(serverSource, /const requestId = cleanString\(request\.headers\?\.\['x-request-id'\]\) \|\| randomUUID\(\)/);
  assert.match(serverSource, /response\.setHeader\('x-request-id', requestId\)/);
  assert.match(serverSource, /from '\.\/observability\.mjs'/);
  assert.match(serverSource, /from '\.\/external-fetch\.mjs'/);
  assert.match(observabilitySource, /function logRequest\(\{ requestId, method, path, status, ms, ip, error \}\)/);
  assert.match(observabilitySource, /function logEvent\(level, event, fields = \{\}\)/);
  assert.match(observabilitySource, /logEvent\([\s\S]*'http_request'/);
  assert.match(externalFetchSource, /async function fetchTextWithTimeoutAndRetry/);
  assert.match(externalFetchSource, /function shouldRetryExternalStatus\(status\)/);
  assert.match(externalFetchSource, /status === 408 \|\| status === 429 \|\| status >= 500/);
  assert.match(authSource, /label: 'google_tokeninfo'/);
  assert.match(dokuSource, /label: 'doku_checkout'/);
  assert.match(envTemplateSource, /GOOGLE_VERIFY_RETRIES=2/);
});

test('deploy and smoke tests run full backend module syntax checks', () => {
  assert.match(deployScriptSource, /npm run check --prefix backend/);
  assert.match(smokeTestSource, /npm run check --prefix backend/);
  assert.doesNotMatch(deployScriptSource, /node --check backend\/src\/server\.mjs/);
  assert.doesNotMatch(smokeTestSource, /node --check backend\/src\/server\.mjs/);
});

test('review decisions are applied through one database transaction', () => {
  assert.match(dbSource, /async function withTransaction\(work\)/);
  assert.match(dbSource, /await client\.query\('BEGIN'\)/);
  assert.match(dbSource, /await client\.query\('COMMIT'\)/);
  assert.match(dbSource, /await client\.query\('ROLLBACK'\)/);
  assert.match(dbSource, /export async function approveReview/);
  assert.match(dbSource, /export async function repeatReview/);
  assert.match(learningSource, /await db\.approveReview\(\{/);
  assert.match(learningSource, /await db\.repeatReview\(\{/);
});

test('audio upload handling enforces size, type, extension, and content sniffing', () => {
  assert.match(serverSource, /MAX_AUDIO_UPLOAD_BYTES/);
  assert.match(serverSource, /const ALLOWED_AUDIO_CONTENT_TYPES = new Set/);
  assert.match(serverSource, /const GENERIC_AUDIO_UPLOAD_CONTENT_TYPES = new Set/);
  assert.match(serverSource, /'application\/octet-stream'/);
  assert.match(serverSource, /const ALLOWED_AUDIO_EXTENSIONS = new Set/);
  assert.match(learningSource, /validateAudioUpload\(\{ originalFileName, contentType, content \}\);/);
  assert.match(learningSource, /throw httpError\(413, 'audio_file_too_large'\)/);
  assert.match(learningSource, /throw httpError\(415, 'unsupported_audio_type'\)/);
  assert.match(learningSource, /throw httpError\(415, 'unsupported_audio_extension'\)/);
  assert.match(learningSource, /throw httpError\(415, 'invalid_audio_file'\)/);
  assert.match(learningSource, /genericAudioUploadContentTypes\.has\(normalizedType\)/);
  assert.match(learningSource, /function looksLikeAudio\(content\)/);
});

test('basic HTTP response hardening is enabled for JSON, files, and admin cookies', () => {
  assert.match(serverSource, /'x-content-type-options': 'nosniff'/);
  assert.match(serverSource, /'vary': 'Origin'/);
  assert.match(serverSource, /function sendCorsPreflight\(response, request\)/);
  assert.match(serverSource, /'access-control-allow-methods': 'GET,POST,PUT,PATCH,OPTIONS'/);
  assert.match(serverSource, /'access-control-max-age': '86400'/);
  assert.match(serverSource, /sendCorsPreflight\(response, request\)/);
  assert.match(serverSource, /function secureCookieAttribute\(\)/);
  assert.match(serverSource, /process\.env\.NODE_ENV === 'production' \? '; Secure' : ''/);
  assert.match(adminSource, /SameSite=Strict; Max-Age=86400\$\{secureCookieAttribute\(\)\}/);
  assert.match(serverSource, /replaceAll\('`', '&#96;'\)/);
});

test('Flutter release build blocks cleartext API traffic and debug signing', () => {
  assert.match(androidManifestSource, /android:usesCleartextTraffic="false"/);
  assert.match(androidDebugManifestSource, /android:usesCleartextTraffic="true"/);
  assert.match(flutterAuthApiSource, /if \(kReleaseMode\) \{/);
  assert.match(flutterAuthApiSource, /IQROKU_API_BASE must use HTTPS in release builds/);
  assert.match(androidBuildGradleSource, /IQROKU_RELEASE_STORE_FILE/);
  assert.match(androidBuildGradleSource, /Release signing is not configured/);
  assert.match(androidBuildGradleSource, /signingConfig = signingConfigs\.getByName\("release"\)/);
  assert.doesNotMatch(androidBuildGradleSource, /signingConfig = signingConfigs\.getByName\("debug"\)/);
});

test('Flutter local child data and dev-only auth tokens are hardened', () => {
  assert.match(flutterLocalStorageSource, /_secureStateKey = 'iqroku\.secure_state\.v1'/);
  assert.match(flutterLocalStorageSource, /_secureStorage\.write\([\s\S]*key: _secureStateKey/);
  assert.match(flutterLocalStorageSource, /preferences\.remove\(_key\)/);
  assert.doesNotMatch(flutterLocalStorageSource, /setString\([\s\S]*excludeSensitive: true/);
  assert.match(flutterAppStateSource, /familyPlusActive = false;/);
  assert.match(flutterAppStateSource, /unawaited\(refreshSubscriptionFromBackend\(\)\)/);
  assert.match(flutterAppStateSource, /emailVerificationDevToken = kDebugMode[\s\S]*result\.emailVerification\?\.devToken[\s\S]*: null/);
  assert.match(flutterAppStateSource, /passwordResetDevToken = kDebugMode[\s\S]*flow\?\.devToken[\s\S]*: null/);
  assert.match(flutterVoiceRecordingSource, /attempt_\$timestamp\.m4a/);
  assert.doesNotMatch(flutterVoiceRecordingSource, /safeChildId/);
  assert.match(flutterPushSource, /void _debugLog\(String message\)/);
  assert.doesNotMatch(flutterPushSource, /Push notification setup failed: \$error/);
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
  assert.match(serverSource, /createNotificationRoutes\(\{/);
  assert.match(serverSource, /notificationRoutes\.handle\(method, path, url, body, request\)/);
  assert.match(notificationSource, /path === '\/devices\/register'/);
  assert.match(notificationSource, /path === '\/devices\/unregister'/);
  assert.match(notificationSource, /const authedParent = await authenticateRequest\(request\);/);
  assert.match(notificationSource, /normalizeDeviceToken\(requiredBody\(body, 'token'\)\)/);
  assert.match(notificationSource, /await enforceChildOwnership\(authedParent\.id, childId\);/);
});

test('notification routes require ownership checks before reads and mutations', () => {
  assert.match(notificationSource, /path === '\/notifications'/);
  assert.match(notificationSource, /path === '\/notifications\/unread-count'/);
  assert.match(notificationSource, /path === '\/notifications\/read-all'/);
  assert.match(notificationSource, /function notificationReadAction\(path\)/);
  assert.match(notificationSource, /db\.findNotificationById\(notificationRead\.id\)/);
  assert.match(notificationSource, /notification\.user_type === 'child'[\s\S]*await enforceChildOwnership\(authedParent\.id, notification\.user_id\)/);
  assert.match(notificationSource, /notification\.user_id !== authedParent\.id[\s\S]*throw httpError\(403, 'access_denied'\)/);
});

test('push sender uses FCM HTTP v1 without firebase-admin dependency', () => {
  assert.match(pushSource, /https:\/\/fcm\.googleapis\.com\/v1\/projects\/\$\{projectId\}\/messages:send/);
  assert.match(pushSource, /createSign\('RSA-SHA256'\)/);
  assert.match(pushSource, /FIREBASE_SERVICE_ACCOUNT_JSON/);
  assert.match(pushSource, /FCM_SEND_RETRIES/);
  assert.match(pushSource, /FCM_OAUTH_RETRIES/);
  assert.match(pushSource, /from '\.\/external-fetch\.mjs'/);
  assert.match(externalFetchSource, /async function fetchJsonWithTimeoutAndRetry/);
  assert.match(pushSource, /label: 'fcm_message_send'/);
  assert.match(pushSource, /label: 'fcm_oauth_token'/);
  assert.match(envTemplateSource, /FCM_SEND_RETRIES=2/);
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
  assert.doesNotMatch(deviceTokensMigration, /\bBEGIN;\b/);
  assert.doesNotMatch(deviceTokensMigration, /\bCOMMIT;\b/);
});

test('migration allows one FCM token to be registered for parent and child roles', () => {
  assert.match(deviceTokenRolesMigration, /DROP CONSTRAINT IF EXISTS device_tokens_token_key/);
  assert.match(deviceTokenRolesMigration, /idx_device_tokens_parent_token/);
  assert.match(deviceTokenRolesMigration, /idx_device_tokens_child_token/);
  assert.doesNotMatch(deviceTokenRolesMigration, /\bBEGIN;\b/);
  assert.doesNotMatch(deviceTokenRolesMigration, /\bCOMMIT;\b/);
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
  assert.doesNotMatch(dokuPaymentsMigration, /\bBEGIN;\b/);
  assert.doesNotMatch(dokuPaymentsMigration, /\bCOMMIT;\b/);
});

test('performance migration indexes hot production query paths', () => {
  assert.match(performanceIndexesMigration, /CREATE INDEX IF NOT EXISTS idx_parents_created/);
  assert.match(performanceIndexesMigration, /CREATE INDEX IF NOT EXISTS idx_sessions_expires/);
  assert.match(performanceIndexesMigration, /CREATE INDEX IF NOT EXISTS idx_auth_tokens_expires_unused/);
  assert.match(performanceIndexesMigration, /CREATE INDEX IF NOT EXISTS idx_attempts_review_created/);
  assert.match(performanceIndexesMigration, /CREATE INDEX IF NOT EXISTS idx_attempts_audio_file_name/);
  assert.match(performanceIndexesMigration, /CREATE INDEX IF NOT EXISTS idx_subscriptions_active_parent/);
  assert.match(performanceIndexesMigration, /CREATE TABLE IF NOT EXISTS subscriptions/);
  assert.match(performanceIndexesMigration, /CREATE INDEX IF NOT EXISTS idx_payment_orders_parent_status_created/);
  assert.match(performanceIndexesMigration, /CREATE INDEX IF NOT EXISTS idx_notifications_user_created/);
  assert.match(performanceIndexesMigration, /CREATE INDEX IF NOT EXISTS idx_device_tokens_active_last_seen/);
  assert.match(performanceIndexesMigration, /WHERE enabled = TRUE/);
  assert.doesNotMatch(performanceIndexesMigration, /idx_notifications_unread_lookup/);
  assert.doesNotMatch(performanceIndexesMigration, /idx_parents_google_id_not_null/);
  assert.doesNotMatch(performanceIndexesMigration, /\bBEGIN;\b/);
  assert.doesNotMatch(performanceIndexesMigration, /\bCOMMIT;\b/);
});

test('security hardening migration removes raw session token dependency and tightens child data constraints', () => {
  assert.match(securityHardeningMigration, /ADD COLUMN IF NOT EXISTS token_hash CHAR\(64\)/);
  assert.match(securityHardeningMigration, /encode\(digest\(token, 'sha256'\), 'hex'\)/);
  assert.match(securityHardeningMigration, /ALTER COLUMN token DROP NOT NULL/);
  assert.match(securityHardeningMigration, /idx_sessions_token_hash/);
  assert.match(securityHardeningMigration, /attempts_book_id_check/);
  assert.match(securityHardeningMigration, /attempts_page_number_check/);
  assert.match(securityHardeningMigration, /children_study_days_check/);
  assert.match(securityHardeningMigration, /children_repeat_progress_check/);
});
