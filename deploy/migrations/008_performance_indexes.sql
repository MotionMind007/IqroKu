BEGIN;

-- Parent/admin listing.
CREATE INDEX IF NOT EXISTS idx_parents_created
  ON parents(created_at DESC);

-- Session/auth cleanup and lookup helpers.
CREATE INDEX IF NOT EXISTS idx_sessions_expires
  ON sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_auth_tokens_expires_unused
  ON auth_tokens(expires_at)
  WHERE used_at IS NULL;

-- Parent dashboard and child progress reads.
CREATE INDEX IF NOT EXISTS idx_children_parent
  ON children(parent_id);

CREATE INDEX IF NOT EXISTS idx_attempts_review_created
  ON attempts(review_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_attempts_audio_file_name
  ON attempts(audio_file_name)
  WHERE audio_file_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_progress_updated
  ON progress(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_progress_review_updated
  ON progress(review_status, updated_at DESC);

-- Subscription/payment dashboard reads.
CREATE INDEX IF NOT EXISTS idx_subscriptions_active_parent
  ON subscriptions(parent_id)
  WHERE active = TRUE;

CREATE INDEX IF NOT EXISTS idx_subscriptions_activated
  ON subscriptions(activated_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_payment_orders_parent_status_created
  ON payment_orders(parent_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payment_orders_expires_pending
  ON payment_orders(expires_at)
  WHERE status = 'pending' AND expires_at IS NOT NULL;

-- Notification feed, unread badge, and mark-all-read.
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON notifications(user_id, user_type, created_at DESC);

-- FCM token lookup/disable paths.
CREATE INDEX IF NOT EXISTS idx_device_tokens_token
  ON device_tokens(token);

CREATE INDEX IF NOT EXISTS idx_device_tokens_active_last_seen
  ON device_tokens(user_type, (COALESCE(child_id, parent_id)), last_seen_at DESC)
  WHERE enabled = TRUE;

-- Daily prayer active list.
CREATE INDEX IF NOT EXISTS idx_daily_prayers_active_sort
  ON daily_prayers(sort_order, title)
  WHERE active = TRUE;

COMMIT;
