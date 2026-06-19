CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE parents
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

UPDATE parents
SET email_verified = TRUE,
    email_verified_at = COALESCE(email_verified_at, created_at),
    updated_at = NOW()
WHERE google_id IS NOT NULL
  AND email_verified = FALSE;

ALTER TABLE attempts
  ADD COLUMN IF NOT EXISTS reviewed_by UUID;

CREATE TABLE IF NOT EXISTS auth_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  purpose VARCHAR(40) NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_children_parent_created
  ON children(parent_id, created_at);

CREATE INDEX IF NOT EXISTS idx_progress_child_book_page
  ON progress(child_id, book_id, page_number);

CREATE INDEX IF NOT EXISTS idx_progress_child_updated
  ON progress(child_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_attempts_child_created
  ON attempts(child_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_attempts_pending_review
  ON attempts(child_id, created_at DESC)
  WHERE review_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_auth_tokens_parent_purpose
  ON auth_tokens(parent_id, purpose, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_auth_tokens_lookup
  ON auth_tokens(purpose, token_hash)
  WHERE used_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_unread_partial
  ON notifications(user_id, user_type, created_at DESC)
  WHERE read = FALSE;

CREATE INDEX IF NOT EXISTS idx_daily_prayers_active_sort
  ON daily_prayers(sort_order, title)
  WHERE active = TRUE;
