ALTER TABLE device_tokens
  DROP CONSTRAINT IF EXISTS device_tokens_token_key;

CREATE UNIQUE INDEX IF NOT EXISTS idx_device_tokens_parent_token
  ON device_tokens(parent_id, token)
  WHERE user_type = 'parent';

CREATE UNIQUE INDEX IF NOT EXISTS idx_device_tokens_child_token
  ON device_tokens(child_id, token)
  WHERE user_type = 'child';
