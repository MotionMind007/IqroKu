import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const serverSource = await readFile(new URL('../src/server.mjs', import.meta.url), 'utf8');
const dbSource = await readFile(new URL('../src/db.mjs', import.meta.url), 'utf8');
const nginxSource = await readFile(new URL('../../deploy/nginx-iqroku.conf', import.meta.url), 'utf8');
const constraintsMigration = await readFile(
  new URL('../../deploy/migrations/002_security_constraints.sql', import.meta.url),
  'utf8',
);

test('demo login is explicitly gated and does not issue deterministic parent-id tokens', () => {
  assert.match(serverSource, /ENABLE_DEMO_LOGIN\s*=\s*process\.env\.ENABLE_DEMO_LOGIN === 'true'/);
  assert.match(serverSource, /if \(!ENABLE_DEMO_LOGIN\)\s*{\s*throw httpError\(404, 'not_found'\);/);
  assert.doesNotMatch(serverSource, /const token = `demo_\$\{parent\.id\}`/);
});

test('public serializers strip PIN hashes from parent and child responses', () => {
  assert.match(serverSource, /const \{ passwordHash, pinHash, \.\.\.safeParent \} = parent;/);
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
  assert.match(serverSource, /const ALLOWED_AUDIO_EXTENSIONS = new Set/);
  assert.match(serverSource, /validateAudioUpload\(\{ originalFileName, contentType, content \}\);/);
  assert.match(serverSource, /throw httpError\(413, 'audio_file_too_large'\)/);
  assert.match(serverSource, /throw httpError\(415, 'unsupported_audio_type'\)/);
  assert.match(serverSource, /throw httpError\(415, 'unsupported_audio_extension'\)/);
  assert.match(serverSource, /throw httpError\(415, 'invalid_audio_file'\)/);
  assert.match(serverSource, /function looksLikeAudio\(content\)/);
});

test('basic HTTP response hardening is enabled for JSON, files, and admin cookies', () => {
  assert.match(serverSource, /'x-content-type-options': 'nosniff'/);
  assert.match(serverSource, /'vary': 'Origin'/);
  assert.match(serverSource, /function secureCookieAttribute\(\)/);
  assert.match(serverSource, /process\.env\.NODE_ENV === 'production' \? '; Secure' : ''/);
  assert.match(serverSource, /SameSite=Strict; Max-Age=86400\$\{secureCookieAttribute\(\)\}/);
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
