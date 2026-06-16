import { createServer } from 'node:http';
import { randomBytes, randomUUID, scryptSync, timingSafeEqual } from 'node:crypto';
import { JsonStore } from './store.mjs';

const store = new JsonStore();
const port = Number(process.env.PORT ?? 8787);

const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url ?? '/', `http://${request.headers.host}`);
    const body = await readJson(request);
    const result = await route(request.method ?? 'GET', url, body);
    const responseStatus = typeof result.status === 'number' ? result.status : 200;
    if (result.html) {
      sendHtml(response, responseStatus, result.html);
      return;
    }
    sendJson(response, responseStatus, result.body ?? result);
  } catch (error) {
    const status = error.statusCode ?? 500;
    sendJson(response, status, {
      error: status === 500 ? 'internal_error' : error.message,
    });
    if (status === 500) {
      console.error(error);
    }
  }
});

server.listen(port, () => {
  console.log(`IqroKu backend listening on http://localhost:${port}`);
});

async function route(method, url, body) {
  const state = await store.load();
  const path = url.pathname;

  if (method === 'OPTIONS') {
    return {};
  }

  if (method === 'GET' && path === '/health') {
    return { ok: true, service: 'iqroku-backend', timestamp: new Date().toISOString() };
  }

  if (method === 'GET' && path === '/admin') {
    return { html: renderAdminDashboard(buildAdminMetrics(state)) };
  }

  if (method === 'GET' && path === '/admin/metrics') {
    return buildAdminMetrics(state);
  }

  if (method === 'GET' && path === '/admin/prayers') {
    return { html: renderAdminPrayers(prayersForAdmin(state)) };
  }

  if (method === 'GET' && path === '/daily-prayers') {
    return publicPrayers(state);
  }

  if (method === 'POST' && path === '/admin/prayers') {
    const prayer = prayerFromBody(body);
    state.dailyPrayers.unshift({
      id: randomUUID(),
      ...prayer,
      active: parseBoolean(body.active, true),
      createdAt: now(),
      updatedAt: now(),
    });
    await store.save();
    return {
      html: renderAdminPrayers(prayersForAdmin(state), 'Doa baru sudah tersimpan.'),
    };
  }

  const prayerAction = adminPrayerAction(path);
  if (method === 'POST' && prayerAction) {
    const prayer = state.dailyPrayers.find((item) => item.id === prayerAction.id);
    if (!prayer) {
      throw httpError(404, 'prayer_not_found');
    }
    if (prayerAction.action === 'delete') {
      state.dailyPrayers = state.dailyPrayers.filter((item) => item.id !== prayer.id);
      await store.save();
      return {
        html: renderAdminPrayers(prayersForAdmin(state), 'Doa sudah dihapus.'),
      };
    }
    Object.assign(prayer, {
      ...prayerFromBody(body),
      active: parseBoolean(body.active, false),
      updatedAt: now(),
    });
    await store.save();
    return {
      html: renderAdminPrayers(prayersForAdmin(state), 'Perubahan doa sudah tersimpan.'),
    };
  }

  if (method === 'POST' && path === '/auth/demo-login') {
    const email = cleanString(body.email) || 'parent@iqroku.local';
    const name = cleanString(body.name) || 'Orang Tua';
    let parent = state.parents.find((item) => item.email === email);
    if (!parent) {
      parent = {
        id: randomUUID(),
        email,
        name,
        createdAt: now(),
      };
      state.parents.push(parent);
      await store.save();
    }
    return { parent: publicParent(parent), session: { token: `demo_${parent.id}`, type: 'demo' } };
  }

  if (method === 'POST' && path === '/auth/register') {
    const name = cleanString(requiredBody(body, 'name'));
    const email = normalizeEmail(requiredBody(body, 'email'));
    const password = cleanString(requiredBody(body, 'password'));
    validatePassword(password);

    const existing = state.parents.find((item) => item.email === email);
    if (existing) {
      throw httpError(409, 'email_already_registered');
    }

    const parent = {
      id: randomUUID(),
      email,
      name,
      passwordHash: hashPassword(password),
      createdAt: now(),
    };
    state.parents.push(parent);
    await store.save();
    return {
      status: 201,
      body: {
        parent: publicParent(parent),
        session: { token: createSessionToken(parent.id), type: 'password' },
      },
    };
  }

  if (method === 'POST' && path === '/auth/login') {
    const email = normalizeEmail(requiredBody(body, 'email'));
    const password = cleanString(requiredBody(body, 'password'));
    const parent = state.parents.find((item) => item.email === email);
    if (!parent || !parent.passwordHash || !verifyPassword(password, parent.passwordHash)) {
      throw httpError(401, 'invalid_email_or_password');
    }

    return {
      parent: publicParent(parent),
      session: { token: createSessionToken(parent.id), type: 'password' },
    };
  }

  if (method === 'GET' && path === '/children') {
    const parentId = requiredQuery(url, 'parentId');
    return state.children.filter((child) => child.parentId === parentId);
  }

  if (method === 'POST' && path === '/children') {
    const parentId = requiredBody(body, 'parentId');
    enforceChildLimit(state, parentId);
    const child = {
      id: randomUUID(),
      parentId,
      name: cleanString(body.name) || 'Anak',
      age: Number(body.age ?? 7),
      avatarAsset: cleanString(body.avatarAsset) || 'assets/brand/male-avatar.png',
      createdAt: now(),
    };
    state.children.push(child);
    await store.save();
    return { status: 201, body: child };
  }

  if (method === 'GET' && path === '/progress') {
    const childId = requiredQuery(url, 'childId');
    return state.progress.filter((item) => item.childId === childId);
  }

  if (method === 'PUT' && path === '/progress') {
    const childId = requiredBody(body, 'childId');
    const bookId = Number(requiredBody(body, 'bookId'));
    const pageNumber = Number(requiredBody(body, 'pageNumber'));
    const status = cleanString(requiredBody(body, 'status'));
    const existing = state.progress.find((item) => {
      return item.childId === childId && item.bookId === bookId && item.pageNumber === pageNumber;
    });
    const record = {
      childId,
      bookId,
      pageNumber,
      status,
      updatedAt: now(),
    };
    if (existing) {
      Object.assign(existing, record);
    } else {
      state.progress.push(record);
    }
    await store.save();
    return record;
  }

  if (method === 'GET' && path === '/attempts') {
    const childId = requiredQuery(url, 'childId');
    return state.attempts.filter((attempt) => attempt.childId === childId);
  }

  if (method === 'POST' && path === '/attempts') {
    const attempt = {
      id: randomUUID(),
      childId: requiredBody(body, 'childId'),
      bookId: Number(requiredBody(body, 'bookId')),
      pageNumber: Number(requiredBody(body, 'pageNumber')),
      durationSeconds: Number(body.durationSeconds ?? 1),
      audioPath: cleanString(body.audioPath),
      assessmentStatus: 'recorded',
      createdAt: now(),
    };
    state.attempts.unshift(attempt);
    await store.save();
    return { status: 201, body: attempt };
  }

  if (method === 'POST' && path === '/assessments/mock') {
    const attemptId = requiredBody(body, 'attemptId');
    const attempt = state.attempts.find((item) => item.id === attemptId);
    if (!attempt) {
      throw httpError(404, 'attempt_not_found');
    }
    const result = scoreAttempt({
      pageNumber: attempt.pageNumber,
      durationSeconds: attempt.durationSeconds,
      targetLines: Array.isArray(body.targetLines) ? body.targetLines : [],
    });
    Object.assign(attempt, {
      ...result,
      assessmentStatus: result.status === 'fluent' ? 'fluent' : 'needsReview',
      assessedAt: now(),
    });
    await store.save();
    return attempt;
  }

  if (method === 'POST' && path === '/subscriptions/activate') {
    const parentId = requiredBody(body, 'parentId');
    const activeUntil = addDays(new Date(), 30).toISOString();
    let subscription = state.subscriptions.find((item) => item.parentId === parentId);
    if (!subscription) {
      subscription = { id: randomUUID(), parentId };
      state.subscriptions.push(subscription);
    }
    Object.assign(subscription, {
      plan: 'plus',
      priceId: 'iqroku_plus_49000_monthly',
      active: true,
      activatedAt: now(),
      activeUntil,
    });
    await store.save();
    return subscription;
  }

  throw httpError(404, 'not_found');
}

async function readJson(request) {
  if (!['POST', 'PUT', 'PATCH'].includes(request.method ?? 'GET')) {
    return {};
  }

  const chunks = [];
  for await (const chunk of request) {
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString('utf8').trim();
  if (!raw) {
    return {};
  }
  const contentType = String(request.headers['content-type'] ?? '');
  if (contentType.includes('application/x-www-form-urlencoded')) {
    return Object.fromEntries(new URLSearchParams(raw));
  }
  return JSON.parse(raw);
}

function sendJson(response, status, body) {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PUT,OPTIONS',
    'access-control-allow-headers': 'content-type,authorization',
  });
  response.end(JSON.stringify(body));
}

function sendHtml(response, status, html) {
  response.writeHead(status, {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
  });
  response.end(html);
}

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeEmail(value) {
  const email = cleanString(value).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw httpError(400, 'invalid_email');
  }
  return email;
}

function validatePassword(password) {
  if (password.length < 6) {
    throw httpError(400, 'password_min_6');
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

function enforceChildLimit(state, parentId) {
  const subscription = state.subscriptions.find((item) => item.parentId === parentId && item.active);
  const limit = subscription ? 5 : 1;
  const count = state.children.filter((child) => child.parentId === parentId).length;
  if (count >= limit) {
    throw httpError(402, 'child_limit_requires_plus');
  }
}

function scoreAttempt({ pageNumber, durationSeconds, targetLines }) {
  const durationScore = Math.min(Math.max(durationSeconds, 1), 12) * 2;
  const pageScore = pageNumber % 5;
  const materialBonus = targetLines.length ? 0 : -5;
  const score = Math.min(Math.max(80 + durationScore + pageScore + materialBonus, 72), 96);
  const passed = score >= 80;
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

function publicPrayers(state) {
  return sortPrayers(state.dailyPrayers)
    .filter((prayer) => prayer.active !== false)
    .map(publicPrayer);
}

function prayersForAdmin(state) {
  return sortPrayers(state.dailyPrayers);
}

function sortPrayers(prayers = []) {
  return [...prayers].sort((a, b) => {
    const sort = Number(a.sortOrder ?? 0) - Number(b.sortOrder ?? 0);
    return sort === 0 ? String(a.title ?? '').localeCompare(String(b.title ?? '')) : sort;
  });
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

function parseBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }
  return ['true', '1', 'yes', 'on'].includes(String(value).toLowerCase());
}

function buildAdminMetrics(state) {
  const activeSubscriptions = state.subscriptions.filter((item) => item.active);
  const activeParentIds = new Set(activeSubscriptions.map((item) => item.parentId));
  const assessedAttempts = state.attempts.filter((attempt) => {
    return attempt.assessedAt || ['fluent', 'needsReview'].includes(attempt.assessmentStatus);
  });
  const fluentPages = state.progress.filter((item) => item.status === 'fluent');
  const reviewPages = state.progress.filter((item) => item.status === 'review');
  const today = new Date().toISOString().slice(0, 10);
  const activeToday = new Set([
    ...state.attempts
      .filter((attempt) => sameDay(attempt.createdAt ?? attempt.assessedAt, today))
      .map((attempt) => childParentId(state, attempt.childId))
      .filter(Boolean),
    ...state.progress
      .filter((item) => sameDay(item.updatedAt, today))
      .map((item) => childParentId(state, item.childId))
      .filter(Boolean),
  ]);

  return {
    generatedAt: now(),
    totals: {
      parents: state.parents.length,
      children: state.children.length,
      freeParents: state.parents.length - activeParentIds.size,
      plusParents: activeParentIds.size,
      activeSubscriptions: activeSubscriptions.length,
      monthlyRevenue: activeSubscriptions.length * 49000,
      attempts: state.attempts.length,
      assessedAttempts: assessedAttempts.length,
      pendingAttempts: Math.max(state.attempts.length - assessedAttempts.length, 0),
      progressRecords: state.progress.length,
      fluentPages: fluentPages.length,
      reviewPages: reviewPages.length,
      activeParentsToday: activeToday.size,
    },
    parents: state.parents
      .toSorted((a, b) => compareDateDesc(a.createdAt, b.createdAt))
      .map((parent) => ({
        ...publicParent(parent),
        plan: activeParentIds.has(parent.id) ? 'IqroKu Plus' : 'Free',
        childrenCount: state.children.filter((child) => child.parentId === parent.id).length,
      })),
    children: state.children.toSorted((a, b) => compareDateDesc(a.createdAt, b.createdAt)),
    subscriptions: state.subscriptions.toSorted((a, b) => compareDateDesc(a.activatedAt, b.activatedAt)),
    attempts: state.attempts
      .toSorted((a, b) => compareDateDesc(a.createdAt ?? a.assessedAt, b.createdAt ?? b.assessedAt))
      .slice(0, 25)
      .map((attempt) => ({
        ...attempt,
        childName: childName(state, attempt.childId),
        parentEmail: childParentEmail(state, attempt.childId),
      })),
  };
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
          <p><a href="/admin/prayers">Kelola Doa</a> · <a href="/admin/metrics">View JSON metrics</a></p>
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
