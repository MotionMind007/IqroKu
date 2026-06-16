import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { JsonStore } from './store.mjs';

const store = new JsonStore();
const port = Number(process.env.PORT ?? 8787);

const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url ?? '/', `http://${request.headers.host}`);
    const body = await readJson(request);
    const result = await route(request.method ?? 'GET', url, body);
    sendJson(response, result.status ?? 200, result.body ?? result);
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

  if (method === 'GET' && path === '/health') {
    return { ok: true, service: 'iqroku-backend', timestamp: new Date().toISOString() };
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
    return { parent, session: { token: `demo_${parent.id}`, type: 'demo' } };
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
  return raw ? JSON.parse(raw) : {};
}

function sendJson(response, status, body) {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
  });
  response.end(JSON.stringify(body));
}

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
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
