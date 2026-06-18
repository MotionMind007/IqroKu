import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const serverSource = await readFile(new URL('../src/server.mjs', import.meta.url), 'utf8');
const nginxSource = await readFile(new URL('../../deploy/nginx-iqroku.conf', import.meta.url), 'utf8');

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
