/**
 * PostgreSQL database layer for IqroKu.
 * Uses node:module to conditionally load 'pg' (postgres driver).
 * Install: npm install pg
 */

import pg from 'pg';

const { Pool } = pg;

let pool;

export function initDb(databaseUrl) {
  pool = new Pool({
    connectionString: databaseUrl,
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });

  pool.on('error', (err) => {
    console.error('Unexpected PostgreSQL pool error:', err.message);
  });

  return pool;
}

export async function closeDb() {
  if (pool) {
    await pool.end();
  }
}

export async function pingDb() {
  const result = await query('SELECT 1 as ok');
  return result.rows[0]?.ok === 1;
}

// Helper: run query
async function query(text, params = []) {
  return pool.query(text, params);
}

// Helper: get single row or null
async function queryOne(text, params = []) {
  const result = await query(text, params);
  return result.rows[0] ?? null;
}

// Helper: get all rows
async function queryAll(text, params = []) {
  const result = await query(text, params);
  return result.rows;
}

// =============================================================================
// PARENTS
// =============================================================================

export async function findParentByEmail(email) {
  const row = await queryOne('SELECT * FROM parents WHERE email = $1', [email]);
  return row ? rowToParent(row) : null;
}

export async function findParentById(id) {
  const row = await queryOne('SELECT * FROM parents WHERE id = $1', [id]);
  return row ? rowToParent(row) : null;
}

export async function createParent({ id, email, name, passwordHash }) {
  const row = await queryOne(
    `INSERT INTO parents (id, email, name, password_hash)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [id, email, name, passwordHash ?? null],
  );
  return rowToParent(row);
}

export async function getAllParents() {
  const rows = await queryAll('SELECT * FROM parents ORDER BY created_at DESC');
  return rows.map(rowToParent);
}

function rowToParent(row) {
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    passwordHash: row.password_hash ?? undefined,
    createdAt: row.created_at?.toISOString(),
  };
}

// =============================================================================
// SESSIONS
// =============================================================================

export async function createSession(token, parentId) {
  await query(
    `INSERT INTO sessions (token, parent_id) VALUES ($1, $2)
     ON CONFLICT (token) DO UPDATE SET parent_id = $2, created_at = NOW(), expires_at = NOW() + INTERVAL '7 days'`,
    [token, parentId],
  );
}

export async function resolveSession(token) {
  const row = await queryOne(
    'SELECT parent_id FROM sessions WHERE token = $1 AND expires_at > NOW()',
    [token],
  );
  return row?.parent_id ?? null;
}

export async function deleteSession(token) {
  await query('DELETE FROM sessions WHERE token = $1', [token]);
}

export async function cleanupExpiredSessions() {
  await query('DELETE FROM sessions WHERE expires_at < NOW()');
}

// =============================================================================
// CHILDREN
// =============================================================================

export async function findChildrenByParent(parentId) {
  const rows = await queryAll(
    'SELECT * FROM children WHERE parent_id = $1 ORDER BY created_at',
    [parentId],
  );
  return rows.map(rowToChild);
}

export async function findChildById(childId) {
  const row = await queryOne('SELECT * FROM children WHERE id = $1', [childId]);
  return row ? rowToChild(row) : null;
}

export async function createChild({ id, parentId, name, age, avatarAsset }) {
  const row = await queryOne(
    `INSERT INTO children (id, parent_id, name, age, avatar_asset)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [id, parentId, name, age, avatarAsset],
  );
  return rowToChild(row);
}

export async function countChildrenByParent(parentId) {
  const row = await queryOne(
    'SELECT COUNT(*)::int AS count FROM children WHERE parent_id = $1',
    [parentId],
  );
  return row?.count ?? 0;
}

export async function getAllChildren() {
  const rows = await queryAll('SELECT * FROM children ORDER BY created_at DESC');
  return rows.map(rowToChild);
}

function rowToChild(row) {
  return {
    id: row.id,
    parentId: row.parent_id,
    name: row.name,
    age: row.age,
    avatarAsset: row.avatar_asset,
    createdAt: row.created_at?.toISOString(),
  };
}

// =============================================================================
// PROGRESS
// =============================================================================

export async function findProgressByChild(childId) {
  const rows = await queryAll(
    'SELECT * FROM progress WHERE child_id = $1',
    [childId],
  );
  return rows.map(rowToProgress);
}

export async function upsertProgress({ childId, bookId, pageNumber, status }) {
  const row = await queryOne(
    `INSERT INTO progress (child_id, book_id, page_number, status, updated_at)
     VALUES ($1, $2, $3, $4, NOW())
     ON CONFLICT (child_id, book_id, page_number)
     DO UPDATE SET status = $4, updated_at = NOW()
     RETURNING *`,
    [childId, bookId, pageNumber, status],
  );
  return rowToProgress(row);
}

export async function getAllProgress() {
  return queryAll('SELECT * FROM progress');
}

function rowToProgress(row) {
  return {
    childId: row.child_id,
    bookId: row.book_id,
    pageNumber: row.page_number,
    status: row.status,
    updatedAt: row.updated_at?.toISOString(),
  };
}

// =============================================================================
// ATTEMPTS
// =============================================================================

export async function findAttemptsByChild(childId) {
  const rows = await queryAll(
    'SELECT * FROM attempts WHERE child_id = $1 ORDER BY created_at DESC',
    [childId],
  );
  return rows.map(rowToAttempt);
}

export async function findAttemptById(attemptId) {
  const row = await queryOne('SELECT * FROM attempts WHERE id = $1', [attemptId]);
  return row ? rowToAttempt(row) : null;
}

export async function createAttempt({ id, childId, bookId, pageNumber, durationSeconds, audioPath }) {
  const row = await queryOne(
    `INSERT INTO attempts (id, child_id, book_id, page_number, duration_seconds, audio_path)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [id, childId, bookId, pageNumber, durationSeconds, audioPath ?? null],
  );
  return rowToAttempt(row);
}

export async function updateAttempt(attemptId, fields) {
  const setClauses = [];
  const values = [];
  let idx = 1;

  const columnMap = {
    audioPath: 'audio_path',
    audioUrl: 'audio_url',
    audioFileName: 'audio_file_name',
    audioContentType: 'audio_content_type',
    audioSizeBytes: 'audio_size_bytes',
    audioUploadedAt: 'audio_uploaded_at',
    assessmentStatus: 'assessment_status',
    score: 'score',
    status: 'status',
    feedback: 'feedback',
    note: 'note',
    assessedAt: 'assessed_at',
  };

  for (const [key, value] of Object.entries(fields)) {
    const column = columnMap[key];
    if (column) {
      setClauses.push(`${column} = $${idx}`);
      values.push(value);
      idx++;
    }
  }

  if (setClauses.length === 0) return null;

  values.push(attemptId);
  const row = await queryOne(
    `UPDATE attempts SET ${setClauses.join(', ')} WHERE id = $${idx} RETURNING *`,
    values,
  );
  return row ? rowToAttempt(row) : null;
}

export async function getRecentAttempts(limit = 25) {
  const rows = await queryAll(
    'SELECT * FROM attempts ORDER BY created_at DESC LIMIT $1',
    [limit],
  );
  return rows.map(rowToAttempt);
}

export async function getAllAttempts() {
  const rows = await queryAll('SELECT * FROM attempts');
  return rows.map(rowToAttempt);
}

function rowToAttempt(row) {
  return {
    id: row.id,
    childId: row.child_id,
    bookId: row.book_id,
    pageNumber: row.page_number,
    durationSeconds: row.duration_seconds,
    audioPath: row.audio_path,
    audioUrl: row.audio_url,
    audioFileName: row.audio_file_name,
    audioContentType: row.audio_content_type,
    audioSizeBytes: row.audio_size_bytes,
    audioUploadedAt: row.audio_uploaded_at?.toISOString(),
    assessmentStatus: row.assessment_status,
    score: row.score,
    status: row.status,
    feedback: row.feedback,
    note: row.note,
    assessedAt: row.assessed_at?.toISOString(),
    createdAt: row.created_at?.toISOString(),
  };
}

// =============================================================================
// SUBSCRIPTIONS
// =============================================================================

export async function findSubscriptionByParent(parentId) {
  const row = await queryOne(
    'SELECT * FROM subscriptions WHERE parent_id = $1',
    [parentId],
  );
  return row ? rowToSubscription(row) : null;
}

export async function upsertSubscription({ id, parentId, plan, priceId, active, activatedAt, activeUntil }) {
  const row = await queryOne(
    `INSERT INTO subscriptions (id, parent_id, plan, price_id, active, activated_at, active_until)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (parent_id)
     DO UPDATE SET plan = $3, price_id = $4, active = $5, activated_at = $6, active_until = $7
     RETURNING *`,
    [id, parentId, plan, priceId, active, activatedAt, activeUntil],
  );
  return rowToSubscription(row);
}

export async function getAllSubscriptions() {
  const rows = await queryAll('SELECT * FROM subscriptions ORDER BY activated_at DESC');
  return rows.map(rowToSubscription);
}

function rowToSubscription(row) {
  return {
    id: row.id,
    parentId: row.parent_id,
    plan: row.plan,
    priceId: row.price_id,
    active: row.active,
    activatedAt: row.activated_at?.toISOString(),
    activeUntil: row.active_until?.toISOString(),
  };
}

// =============================================================================
// DAILY PRAYERS
// =============================================================================

export async function getActivePrayers() {
  const rows = await queryAll(
    'SELECT * FROM daily_prayers WHERE active = TRUE ORDER BY sort_order, title',
  );
  return rows.map(rowToPrayer);
}

export async function getAllPrayers() {
  const rows = await queryAll(
    'SELECT * FROM daily_prayers ORDER BY sort_order, title',
  );
  return rows.map(rowToPrayer);
}

export async function findPrayerById(id) {
  const row = await queryOne('SELECT * FROM daily_prayers WHERE id = $1', [id]);
  return row ? rowToPrayer(row) : null;
}

export async function createPrayer({ id, title, category, arabic, latin, meaning, sortOrder, active }) {
  const row = await queryOne(
    `INSERT INTO daily_prayers (id, title, category, arabic, latin, meaning, sort_order, active)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [id, title, category, arabic, latin ?? '', meaning, sortOrder, active],
  );
  return rowToPrayer(row);
}

export async function updatePrayer(id, { title, category, arabic, latin, meaning, sortOrder, active }) {
  const row = await queryOne(
    `UPDATE daily_prayers
     SET title = $2, category = $3, arabic = $4, latin = $5, meaning = $6,
         sort_order = $7, active = $8, updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [id, title, category, arabic, latin ?? '', meaning, sortOrder, active],
  );
  return row ? rowToPrayer(row) : null;
}

export async function deletePrayer(id) {
  await query('DELETE FROM daily_prayers WHERE id = $1', [id]);
}

function rowToPrayer(row) {
  return {
    id: row.id,
    title: row.title,
    category: row.category,
    arabic: row.arabic,
    latin: row.latin,
    meaning: row.meaning,
    sortOrder: row.sort_order,
    active: row.active,
    createdAt: row.created_at?.toISOString(),
    updatedAt: row.updated_at?.toISOString(),
  };
}

// =============================================================================
// ADMIN METRICS (aggregated queries)
// =============================================================================

export async function getAdminMetrics() {
  const [
    parents,
    children,
    subscriptions,
    attempts,
    progress,
    prayers,
  ] = await Promise.all([
    getAllParents(),
    getAllChildren(),
    getAllSubscriptions(),
    getRecentAttempts(25),
    getAllProgress(),
    getAllPrayers(),
  ]);

  const allAttempts = await queryAll('SELECT COUNT(*)::int AS total FROM attempts');
  const assessedAttempts = await queryAll(
    `SELECT COUNT(*)::int AS total FROM attempts
     WHERE assessed_at IS NOT NULL OR assessment_status IN ('fluent', 'needsReview')`,
  );

  const activeSubscriptions = subscriptions.filter((s) => s.active);
  const activeParentIds = new Set(activeSubscriptions.map((s) => s.parentId));
  const fluentPages = progress.filter((p) => p.status === 'fluent');
  const reviewPages = progress.filter((p) => p.status === 'review');

  const today = new Date().toISOString().slice(0, 10);
  const childParentMap = new Map(children.map((c) => [c.id, c.parentId]));

  // Active today: recent attempts or progress updates from today
  const todayAttempts = await queryAll(
    `SELECT DISTINCT child_id FROM attempts WHERE created_at::date = $1`,
    [today],
  );
  const todayProgress = await queryAll(
    `SELECT DISTINCT child_id FROM progress WHERE updated_at::date = $1`,
    [today],
  );
  const activeToday = new Set([
    ...todayAttempts.map((r) => childParentMap.get(r.child_id)).filter(Boolean),
    ...todayProgress.map((r) => childParentMap.get(r.child_id)).filter(Boolean),
  ]);

  return {
    generatedAt: new Date().toISOString(),
    totals: {
      parents: parents.length,
      children: children.length,
      freeParents: parents.length - activeParentIds.size,
      plusParents: activeParentIds.size,
      activeSubscriptions: activeSubscriptions.length,
      monthlyRevenue: activeSubscriptions.length * 49000,
      attempts: allAttempts[0]?.total ?? 0,
      assessedAttempts: assessedAttempts[0]?.total ?? 0,
      pendingAttempts: Math.max((allAttempts[0]?.total ?? 0) - (assessedAttempts[0]?.total ?? 0), 0),
      progressRecords: progress.length,
      fluentPages: fluentPages.length,
      reviewPages: reviewPages.length,
      activeParentsToday: activeToday.size,
    },
    parents: parents.map((parent) => ({
      ...parent,
      plan: activeParentIds.has(parent.id) ? 'IqroKu Plus' : 'Free',
      childrenCount: children.filter((c) => c.parentId === parent.id).length,
    })),
    children,
    subscriptions,
    attempts: attempts.map((attempt) => {
      const child = children.find((c) => c.id === attempt.childId);
      const parentEmail = parents.find((p) => p.id === child?.parentId)?.email ?? '';
      return {
        ...attempt,
        childName: child?.name ?? 'Unknown',
        parentEmail,
      };
    }),
  };
}
