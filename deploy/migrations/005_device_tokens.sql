BEGIN;

CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  child_id UUID REFERENCES children(id) ON DELETE CASCADE,
  user_type VARCHAR(10) NOT NULL DEFAULT 'parent'
    CHECK (user_type IN ('parent', 'child')),
  token TEXT NOT NULL UNIQUE,
  platform VARCHAR(20) NOT NULL DEFAULT 'android'
    CHECK (platform IN ('android', 'ios', 'web', 'unknown')),
  app_version VARCHAR(80),
  device_model VARCHAR(200),
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (
    (user_type = 'parent' AND child_id IS NULL)
    OR (user_type = 'child' AND child_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_parent
  ON device_tokens(parent_id, enabled, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user
  ON device_tokens(user_type, (COALESCE(child_id, parent_id)), enabled);

COMMIT;
