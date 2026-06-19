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

async function withTransaction(work) {
  const client = await pool.connect();
  const tx = {
    query: (text, params = []) => client.query(text, params),
    queryOne: async (text, params = []) => {
      const result = await client.query(text, params);
      return result.rows[0] ?? null;
    },
  };
  try {
    await client.query('BEGIN');
    const result = await work(tx);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
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

export async function createParent({ id, email, name, passwordHash, googleId }) {
  const row = await queryOne(
    `INSERT INTO parents (id, email, name, password_hash, google_id, email_verified, email_verified_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      id,
      email,
      name,
      passwordHash ?? null,
      googleId ?? null,
      Boolean(googleId),
      googleId ? new Date().toISOString() : null,
    ],
  );
  return rowToParent(row);
}

export async function updateParent(id, updates) {
  const allowedFields = ['name', 'google_id'];
  const setClauses = [];
  const values = [];
  let paramIndex = 1;

  for (const [key, value] of Object.entries(updates)) {
    const dbKey = key === 'googleId' ? 'google_id' : key;
    if (allowedFields.includes(dbKey)) {
      setClauses.push(`${dbKey} = $${paramIndex}`);
      values.push(value);
      paramIndex++;
    }
  }

  if (setClauses.length === 0) {
    return findParentById(id);
  }

  values.push(id);
  const row = await queryOne(
    `UPDATE parents SET ${setClauses.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
    values,
  );
  return row ? rowToParent(row) : null;
}

export async function markParentEmailVerified(parentId) {
  const row = await queryOne(
    `UPDATE parents
     SET email_verified = TRUE,
         email_verified_at = COALESCE(email_verified_at, NOW()),
         updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [parentId],
  );
  return row ? rowToParent(row) : null;
}

export async function updateParentPassword(parentId, passwordHash) {
  const row = await queryOne(
    `UPDATE parents
     SET password_hash = $1,
         updated_at = NOW()
     WHERE id = $2
     RETURNING *`,
    [passwordHash, parentId],
  );
  return row ? rowToParent(row) : null;
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
    googleId: row.google_id ?? undefined,
    pinHash: row.pin_hash ?? undefined,
    emailVerified: row.email_verified === true,
    emailVerifiedAt: row.email_verified_at?.toISOString(),
    updatedAt: row.updated_at?.toISOString(),
    createdAt: row.created_at?.toISOString(),
  };
}

// =============================================================================
// AUTH TOKENS
// =============================================================================

export async function createAuthToken({ parentId, purpose, tokenHash, expiresAt, metadata }) {
  const row = await queryOne(
    `INSERT INTO auth_tokens (parent_id, purpose, token_hash, expires_at, metadata)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [parentId, purpose, tokenHash, expiresAt, metadata ? JSON.stringify(metadata) : null],
  );
  return rowToAuthToken(row);
}

export async function findValidAuthToken({ purpose, tokenHash }) {
  const row = await queryOne(
    `SELECT * FROM auth_tokens
     WHERE purpose = $1
       AND token_hash = $2
       AND used_at IS NULL
       AND expires_at > NOW()`,
    [purpose, tokenHash],
  );
  return row ? rowToAuthToken(row) : null;
}

export async function markAuthTokenUsed(id) {
  await query('UPDATE auth_tokens SET used_at = NOW() WHERE id = $1', [id]);
}

export async function revokeAuthTokens(parentId, purpose) {
  await query(
    `UPDATE auth_tokens
     SET used_at = NOW()
     WHERE parent_id = $1 AND purpose = $2 AND used_at IS NULL`,
    [parentId, purpose],
  );
}

export async function cleanupExpiredAuthTokens() {
  await query('DELETE FROM auth_tokens WHERE expires_at < NOW() - INTERVAL \'7 days\'');
}

function rowToAuthToken(row) {
  return {
    id: row.id,
    parentId: row.parent_id,
    purpose: row.purpose,
    tokenHash: row.token_hash,
    expiresAt: row.expires_at?.toISOString(),
    usedAt: row.used_at?.toISOString(),
    metadata: row.metadata,
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
    pinHash: row.pin_hash ?? undefined,
    studyStartTime: row.study_start_time ?? undefined,
    studyEndTime: row.study_end_time ?? undefined,
    studyDays: row.study_days ?? [1, 2, 3, 4, 5],
    repeatFromPage: row.repeat_from_page ?? 1,
    repeatFromBook: row.repeat_from_book ?? 1,
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

export async function findAttemptByAudioFileName(fileName) {
  const row = await queryOne(
    'SELECT * FROM attempts WHERE audio_file_name = $1',
    [fileName],
  );
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
    reviewStatus: row.review_status,
    reviewedAt: row.reviewed_at?.toISOString(),
    reviewedBy: row.reviewed_by ?? undefined,
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
  const parentListLimit = 100;
  const subscriptionListLimit = 100;
  const attemptListLimit = 25;
  const today = new Date().toISOString().slice(0, 10);

  const [
    totals,
    attemptTotals,
    progressTotals,
    activeToday,
    parents,
    subscriptions,
    attempts,
  ] = await Promise.all([
    queryOne(
      `SELECT
         COUNT(*)::int AS parents,
         COALESCE((SELECT COUNT(*)::int FROM children), 0) AS children,
         COALESCE((SELECT COUNT(DISTINCT parent_id)::int FROM subscriptions WHERE active = TRUE), 0) AS plus_parents,
         COALESCE((SELECT COUNT(*)::int FROM subscriptions WHERE active = TRUE), 0) AS active_subscriptions`,
    ),
    queryOne(
      `SELECT
         COUNT(*)::int AS attempts,
         COUNT(*) FILTER (
           WHERE assessed_at IS NOT NULL OR assessment_status IN ('fluent', 'needsReview')
         )::int AS assessed_attempts
       FROM attempts`,
    ),
    queryOne(
      `SELECT
         COUNT(*)::int AS progress_records,
         COUNT(*) FILTER (WHERE status = 'fluent')::int AS fluent_pages,
         COUNT(*) FILTER (WHERE status = 'review')::int AS review_pages
       FROM progress`,
    ),
    queryOne(
      `SELECT COUNT(DISTINCT c.parent_id)::int AS total
       FROM children c
       WHERE EXISTS (
         SELECT 1 FROM attempts a
         WHERE a.child_id = c.id AND a.created_at::date = $1
       )
       OR EXISTS (
         SELECT 1 FROM progress p
         WHERE p.child_id = c.id AND p.updated_at::date = $1
       )`,
      [today],
    ),
    queryAll(
      `SELECT
         p.id,
         p.email,
         p.name,
         p.created_at,
         CASE
           WHEN active_sub.parent_id IS NULL THEN 'Free'
           ELSE 'IqroKu Plus'
         END AS plan,
         COUNT(c.id)::int AS children_count
       FROM parents p
       LEFT JOIN (
         SELECT DISTINCT parent_id
         FROM subscriptions
         WHERE active = TRUE
       ) active_sub ON active_sub.parent_id = p.id
       LEFT JOIN children c ON c.parent_id = p.id
       GROUP BY p.id, p.email, p.name, p.created_at, active_sub.parent_id
       ORDER BY p.created_at DESC
       LIMIT $1`,
      [parentListLimit],
    ),
    queryAll(
      `SELECT s.*, p.email AS parent_email
       FROM subscriptions s
       LEFT JOIN parents p ON p.id = s.parent_id
       ORDER BY s.activated_at DESC NULLS LAST
       LIMIT $1`,
      [subscriptionListLimit],
    ),
    queryAll(
      `SELECT a.*, c.name AS child_name, p.email AS parent_email
       FROM attempts a
       LEFT JOIN children c ON c.id = a.child_id
       LEFT JOIN parents p ON p.id = c.parent_id
       ORDER BY a.created_at DESC
       LIMIT $1`,
      [attemptListLimit],
    ),
  ]);

  return {
    generatedAt: new Date().toISOString(),
    totals: {
      parents: totals?.parents ?? 0,
      children: totals?.children ?? 0,
      freeParents: Math.max((totals?.parents ?? 0) - (totals?.plus_parents ?? 0), 0),
      plusParents: totals?.plus_parents ?? 0,
      activeSubscriptions: totals?.active_subscriptions ?? 0,
      monthlyRevenue: (totals?.active_subscriptions ?? 0) * 49000,
      attempts: attemptTotals?.attempts ?? 0,
      assessedAttempts: attemptTotals?.assessed_attempts ?? 0,
      pendingAttempts: Math.max(
        (attemptTotals?.attempts ?? 0) - (attemptTotals?.assessed_attempts ?? 0),
        0,
      ),
      progressRecords: progressTotals?.progress_records ?? 0,
      fluentPages: progressTotals?.fluent_pages ?? 0,
      reviewPages: progressTotals?.review_pages ?? 0,
      activeParentsToday: activeToday?.total ?? 0,
    },
    limits: {
      parents: parentListLimit,
      subscriptions: subscriptionListLimit,
      attempts: attemptListLimit,
    },
    parents: parents.map((row) => ({
      id: row.id,
      email: row.email,
      name: row.name,
      plan: row.plan,
      childrenCount: row.children_count,
      createdAt: row.created_at?.toISOString(),
    })),
    subscriptions: subscriptions.map((row) => ({
      ...rowToSubscription(row),
      parentEmail: row.parent_email ?? '',
    })),
    attempts: attempts.map((row) => ({
      ...rowToAttempt(row),
      childName: row.child_name ?? 'Unknown',
      parentEmail: row.parent_email ?? '',
    })),
  };
}

// =============================================================================
// PIN MANAGEMENT
// =============================================================================

export async function setParentPin(parentId, pinHash) {
  const row = await queryOne(
    'UPDATE parents SET pin_hash = $1 WHERE id = $2 RETURNING *',
    [pinHash, parentId],
  );
  return row ? rowToParent(row) : null;
}

export async function verifyParentPin(parentId, pinHash) {
  const row = await queryOne(
    'SELECT id FROM parents WHERE id = $1 AND pin_hash = $2',
    [parentId, pinHash],
  );
  return row !== null;
}

export async function setChildPin(childId, pinHash) {
  const row = await queryOne(
    'UPDATE children SET pin_hash = $1 WHERE id = $2 RETURNING *',
    [pinHash, childId],
  );
  return row ? rowToChild(row) : null;
}

export async function verifyChildPin(childId, pinHash) {
  const row = await queryOne(
    'SELECT id FROM children WHERE id = $1 AND pin_hash = $2',
    [childId, pinHash],
  );
  return row !== null;
}

export async function findChildByPin(parentId, pinHash) {
  const row = await queryOne(
    'SELECT * FROM children WHERE parent_id = $1 AND pin_hash = $2',
    [parentId, pinHash],
  );
  return row ? rowToChild(row) : null;
}

// =============================================================================
// STUDY SCHEDULE
// =============================================================================

export async function updateChildSchedule(childId, startTime, endTime, days) {
  const row = await queryOne(
    `UPDATE children SET study_start_time = $1, study_end_time = $2, study_days = $3
     WHERE id = $4 RETURNING *`,
    [startTime, endTime, days, childId],
  );
  return row ? rowToChild(row) : null;
}

// =============================================================================
// REVIEW STATUS
// =============================================================================

export async function updateProgressReview(childId, bookId, pageNumber, reviewStatus, reviewedBy) {
  return updateProgressReviewWith({ queryOne }, childId, bookId, pageNumber, reviewStatus, reviewedBy);
}

async function updateProgressReviewWith(dbClient, childId, bookId, pageNumber, reviewStatus, reviewedBy) {
  const row = await dbClient.queryOne(
    `UPDATE progress SET review_status = $1, reviewed_at = NOW(), reviewed_by = $2
     WHERE child_id = $3 AND book_id = $4 AND page_number = $5 RETURNING *`,
    [reviewStatus, reviewedBy, childId, bookId, pageNumber],
  );
  return row;
}

export async function updateAttemptReview(attemptId, reviewStatus, reviewedBy) {
  return updateAttemptReviewWith({ queryOne }, attemptId, reviewStatus, reviewedBy);
}

async function updateAttemptReviewWith(dbClient, attemptId, reviewStatus, reviewedBy) {
  const assessmentStatus = reviewStatus === 'approved'
    ? 'fluent'
    : reviewStatus === 'needs_repeat'
      ? 'needsReview'
      : 'recorded';
  const status = reviewStatus === 'approved'
    ? 'fluent'
    : reviewStatus === 'needs_repeat'
      ? 'review'
      : 'learning';
  const row = await dbClient.queryOne(
    `UPDATE attempts
     SET review_status = $1,
         reviewed_at = NOW(),
         reviewed_by = $5,
         assessment_status = $2,
         status = $3
     WHERE id = $4 RETURNING *`,
    [reviewStatus, assessmentStatus, status, attemptId, reviewedBy],
  );
  return row;
}

export async function setRepeatFromPage(childId, bookId, pageNumber) {
  return setRepeatFromPageWith({ queryOne }, childId, bookId, pageNumber);
}

async function setRepeatFromPageWith(dbClient, childId, bookId, pageNumber) {
  const row = await dbClient.queryOne(
    'UPDATE children SET repeat_from_page = $1, repeat_from_book = $2 WHERE id = $3 RETURNING *',
    [pageNumber, bookId, childId],
  );
  return row ? rowToChild(row) : null;
}

async function upsertProgressWith(dbClient, { childId, bookId, pageNumber, status }) {
  const row = await dbClient.queryOne(
    `INSERT INTO progress (child_id, book_id, page_number, status, updated_at)
     VALUES ($1, $2, $3, $4, NOW())
     ON CONFLICT (child_id, book_id, page_number)
     DO UPDATE SET status = $4, updated_at = NOW()
     RETURNING *`,
    [childId, bookId, pageNumber, status],
  );
  return rowToProgress(row);
}

async function createNotificationWith(dbClient, { userId, userType, type, title, message, data }) {
  const row = await dbClient.queryOne(
    `INSERT INTO notifications (id, user_id, user_type, type, title, message, data)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [userId, userType, type, title, message, data ? JSON.stringify(data) : null],
  );
  return row;
}

export async function approveReview({ attempt, reviewedBy }) {
  return withTransaction(async (tx) => {
    await updateAttemptReviewWith(tx, attempt.id, 'approved', reviewedBy);
    await upsertProgressWith(tx, {
      childId: attempt.childId,
      bookId: attempt.bookId,
      pageNumber: attempt.pageNumber,
      status: 'fluent',
    });
    await updateProgressReviewWith(
      tx,
      attempt.childId,
      attempt.bookId,
      attempt.pageNumber,
      'approved',
      reviewedBy,
    );
    return createNotificationWith(tx, {
      userId: attempt.childId,
      userType: 'child',
      type: 'review_result',
      title: 'Bacaan Direview',
      message: `Bacaan halaman ${attempt.pageNumber} sudah direview. Kamu bisa lanjut!`,
      data: {
        attemptId: attempt.id,
        bookId: attempt.bookId,
        pageNumber: attempt.pageNumber,
        result: 'approved',
      },
    });
  });
}

export async function repeatReview({ attempt, reviewedBy, fromPage }) {
  return withTransaction(async (tx) => {
    await updateAttemptReviewWith(tx, attempt.id, 'needs_repeat', reviewedBy);
    await upsertProgressWith(tx, {
      childId: attempt.childId,
      bookId: attempt.bookId,
      pageNumber: fromPage,
      status: 'review',
    });
    await setRepeatFromPageWith(tx, attempt.childId, attempt.bookId, fromPage);
    await updateProgressReviewWith(
      tx,
      attempt.childId,
      attempt.bookId,
      fromPage,
      'needs_repeat',
      reviewedBy,
    );
    return createNotificationWith(tx, {
      userId: attempt.childId,
      userType: 'child',
      type: 'review_result',
      title: 'Perlu Mengulang',
      message: `Bacaan perlu diulang dari halaman ${fromPage}. Semangat!`,
      data: {
        attemptId: attempt.id,
        bookId: attempt.bookId,
        pageNumber: attempt.pageNumber,
        fromPage,
        result: 'needs_repeat',
      },
    });
  });
}

export async function getPendingReviews(parentId) {
  const rows = await queryAll(
    `SELECT a.*, c.name as child_name, c.parent_id
     FROM attempts a
     JOIN children c ON a.child_id = c.id
     WHERE c.parent_id = $1 AND a.review_status = 'pending'
     ORDER BY a.created_at DESC`,
    [parentId],
  );
  return rows;
}

// =============================================================================
// NOTIFICATIONS
// =============================================================================

export async function createNotification({ userId, userType, type, title, message, data }) {
  const row = await queryOne(
    `INSERT INTO notifications (id, user_id, user_type, type, title, message, data)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [userId, userType, type, title, message, data ? JSON.stringify(data) : null],
  );
  return row;
}

export async function getNotifications(userId, userType, limit = 20) {
  const rows = await queryAll(
    `SELECT * FROM notifications
     WHERE user_id = $1 AND user_type = $2
     ORDER BY created_at DESC
     LIMIT $3`,
    [userId, userType, limit],
  );
  return rows;
}

export async function getUnreadNotifications(userId, userType) {
  const rows = await queryAll(
    `SELECT * FROM notifications
     WHERE user_id = $1 AND user_type = $2 AND read = FALSE
     ORDER BY created_at DESC`,
    [userId, userType],
  );
  return rows;
}

export async function findNotificationById(notificationId) {
  return queryOne('SELECT * FROM notifications WHERE id = $1', [notificationId]);
}

export async function markNotificationRead(notificationId) {
  await query(
    'UPDATE notifications SET read = TRUE WHERE id = $1',
    [notificationId],
  );
}

export async function markAllNotificationsRead(userId, userType) {
  await query(
    'UPDATE notifications SET read = TRUE WHERE user_id = $1 AND user_type = $2',
    [userId, userType],
  );
}

export async function countUnreadNotifications(userId, userType) {
  const row = await queryOne(
    'SELECT COUNT(*)::int AS count FROM notifications WHERE user_id = $1 AND user_type = $2 AND read = FALSE',
    [userId, userType],
  );
  return row?.count ?? 0;
}

// =============================================================================
// DEVICE TOKENS
// =============================================================================

export async function upsertDeviceToken({
  parentId,
  childId,
  userType,
  token,
  platform,
  appVersion,
  deviceModel,
}) {
  return withTransaction(async (tx) => {
    const existing = await tx.queryOne(
      `SELECT id
       FROM device_tokens
       WHERE token = $1
         AND user_type = $2
         AND (
           ($2 = 'parent' AND parent_id = $3 AND child_id IS NULL)
           OR ($2 = 'child' AND child_id = $4)
         )
       LIMIT 1`,
      [token, userType, parentId, childId ?? null],
    );

    const values = [
      parentId,
      childId ?? null,
      userType,
      token,
      platform,
      appVersion ?? null,
      deviceModel ?? null,
    ];

    if (existing) {
      const row = await tx.queryOne(
        `UPDATE device_tokens
         SET parent_id = $1,
             child_id = $2,
             user_type = $3,
             token = $4,
             platform = $5,
             app_version = $6,
             device_model = $7,
             enabled = TRUE,
             last_seen_at = NOW(),
             updated_at = NOW()
         WHERE id = $8
         RETURNING *`,
        [...values, existing.id],
      );
      return rowToDeviceToken(row);
    }

    const row = await tx.queryOne(
      `INSERT INTO device_tokens (
         parent_id,
         child_id,
         user_type,
         token,
         platform,
         app_version,
         device_model,
         enabled,
         last_seen_at,
         updated_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE, NOW(), NOW())
       RETURNING *`,
      values,
    );
    return rowToDeviceToken(row);
  });
}

export async function disableDeviceToken({ parentId, token }) {
  const row = await queryOne(
    `UPDATE device_tokens
     SET enabled = FALSE, updated_at = NOW()
     WHERE parent_id = $1 AND token = $2
     RETURNING *`,
    [parentId, token],
  );
  return row ? rowToDeviceToken(row) : null;
}

export async function disableDeviceTokenByToken(token) {
  await query(
    `UPDATE device_tokens
     SET enabled = FALSE, updated_at = NOW()
     WHERE token = $1`,
    [token],
  );
}

export async function getActiveDeviceTokens(userId, userType) {
  const rows = await queryAll(
    `SELECT *
     FROM device_tokens
     WHERE user_type = $1
       AND enabled = TRUE
       AND COALESCE(child_id, parent_id) = $2
     ORDER BY last_seen_at DESC`,
    [userType, userId],
  );
  return rows.map(rowToDeviceToken);
}

function rowToDeviceToken(row) {
  return {
    id: row.id,
    parentId: row.parent_id,
    childId: row.child_id ?? undefined,
    userType: row.user_type,
    token: row.token,
    platform: row.platform,
    appVersion: row.app_version ?? undefined,
    deviceModel: row.device_model ?? undefined,
    enabled: row.enabled === true,
    lastSeenAt: row.last_seen_at?.toISOString(),
    createdAt: row.created_at?.toISOString(),
    updatedAt: row.updated_at?.toISOString(),
  };
}

// =============================================================================
// CHILDREN SCHEDULE CHECK
// =============================================================================

export async function getChildrenWithoutPracticeToday() {
  const today = new Date().toISOString().slice(0, 10);
  const dayOfWeek = new Date().getDay(); // 0=Sun, 1=Mon, ...
  const dbDay = dayOfWeek === 0 ? 7 : dayOfWeek; // Convert to 1=Mon, 7=Sun

  const rows = await queryAll(
    `SELECT c.* FROM children c
     WHERE $1 = ANY(c.study_days)
     AND c.id NOT IN (
       SELECT DISTINCT child_id FROM attempts WHERE created_at::date = $2
     )
     AND c.id NOT IN (
       SELECT DISTINCT child_id FROM progress WHERE updated_at::date = $2
     )`,
    [dbDay, today],
  );
  return rows.map(rowToChild);
}
