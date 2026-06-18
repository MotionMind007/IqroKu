-- IqroKu PostgreSQL Schema
-- Run: psql -U iqroku -d iqroku_db -f schema.sql

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Parents (users)
CREATE TABLE IF NOT EXISTS parents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(254) UNIQUE NOT NULL,
  name VARCHAR(200) NOT NULL,
  password_hash TEXT,
  google_id VARCHAR(100),
  pin_hash TEXT, -- 4-digit PIN for parent mode
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  email_verified_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_parents_email ON parents(email);
CREATE INDEX idx_parents_google_id ON parents(google_id);

-- Idempotent migration bookkeeping
CREATE TABLE IF NOT EXISTS schema_migrations (
  name TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Sessions
CREATE TABLE IF NOT EXISTS sessions (
  token VARCHAR(128) PRIMARY KEY,
  parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days')
);

CREATE INDEX idx_sessions_parent ON sessions(parent_id);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);

-- Children profiles
CREATE TABLE IF NOT EXISTS children (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL DEFAULT 'Anak',
  age SMALLINT NOT NULL DEFAULT 7 CHECK (age BETWEEN 1 AND 18),
  avatar_asset VARCHAR(500) NOT NULL DEFAULT 'assets/brand/male-avatar.png',
  pin_hash TEXT, -- 4-digit PIN for child mode
  study_start_time TIME, -- study schedule start
  study_end_time TIME, -- study schedule end
  study_days INTEGER[] DEFAULT '{1,2,3,4,5}', -- 1=Mon, 7=Sun
  repeat_from_page INTEGER DEFAULT 1, -- page to restart from after review
  repeat_from_book INTEGER DEFAULT 1, -- book to restart from after review
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_children_parent ON children(parent_id);
CREATE INDEX idx_children_parent_created ON children(parent_id, created_at);

-- Learning progress per page
CREATE TABLE IF NOT EXISTS progress (
  id BIGSERIAL PRIMARY KEY,
  child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
  book_id SMALLINT NOT NULL CHECK (book_id BETWEEN 1 AND 99),
  page_number SMALLINT NOT NULL CHECK (page_number BETWEEN 1 AND 999),
  status VARCHAR(20) NOT NULL DEFAULT 'notStarted',
  review_status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'needs_repeat'
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (child_id, book_id, page_number)
);

CREATE INDEX idx_progress_child ON progress(child_id);
CREATE INDEX idx_progress_child_book_page ON progress(child_id, book_id, page_number);
CREATE INDEX idx_progress_child_updated ON progress(child_id, updated_at DESC);
CREATE INDEX idx_progress_review ON progress(review_status);

-- Reading attempts (voice recordings)
CREATE TABLE IF NOT EXISTS attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
  book_id SMALLINT NOT NULL,
  page_number SMALLINT NOT NULL,
  duration_seconds INTEGER NOT NULL DEFAULT 1,
  audio_path VARCHAR(500),
  audio_url VARCHAR(500),
  audio_file_name VARCHAR(200),
  audio_content_type VARCHAR(100),
  audio_size_bytes INTEGER,
  audio_uploaded_at TIMESTAMPTZ,
  assessment_status VARCHAR(30) NOT NULL DEFAULT 'recorded',
  review_status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'needs_repeat'
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID,
  score SMALLINT,
  status VARCHAR(20),
  feedback TEXT,
  note TEXT,
  assessed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attempts_child ON attempts(child_id);
CREATE INDEX idx_attempts_child_created ON attempts(child_id, created_at DESC);
CREATE INDEX idx_attempts_created ON attempts(created_at DESC);
CREATE INDEX idx_attempts_review ON attempts(review_status);
CREATE INDEX idx_attempts_pending_review ON attempts(child_id, created_at DESC)
  WHERE review_status = 'pending';

-- One-time auth flow tokens. Raw tokens are never stored, only SHA-256 hashes.
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

CREATE INDEX idx_auth_tokens_parent_purpose ON auth_tokens(parent_id, purpose, created_at DESC);
CREATE INDEX idx_auth_tokens_lookup ON auth_tokens(purpose, token_hash)
  WHERE used_at IS NULL;

-- Subscriptions
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  plan VARCHAR(50) NOT NULL DEFAULT 'plus',
  price_id VARCHAR(100),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  activated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  active_until TIMESTAMPTZ,
  UNIQUE (parent_id)
);

CREATE INDEX idx_subscriptions_parent ON subscriptions(parent_id);

-- Notifications
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL, -- parent_id or child_id
  user_type VARCHAR(10) NOT NULL, -- 'parent' or 'child'
  type VARCHAR(50) NOT NULL, -- 'new_recording', 'no_practice', 'review_result'
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  read BOOLEAN DEFAULT FALSE,
  data JSONB, -- {child_id, book_id, page_start, page_end, etc}
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, user_type);
CREATE INDEX idx_notifications_unread ON notifications(user_id, user_type, read);
CREATE INDEX idx_notifications_unread_partial ON notifications(user_id, user_type, created_at DESC)
  WHERE read = FALSE;

-- Daily prayers content
CREATE TABLE IF NOT EXISTS daily_prayers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(200) NOT NULL,
  category VARCHAR(100) NOT NULL DEFAULT 'Harian',
  arabic TEXT NOT NULL,
  latin TEXT,
  meaning TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 100,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_prayers_active ON daily_prayers(active, sort_order);
CREATE INDEX idx_daily_prayers_active_sort ON daily_prayers(sort_order, title)
  WHERE active = TRUE;

-- Seed default prayers
INSERT INTO daily_prayers (id, title, category, arabic, latin, meaning, sort_order) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Doa Sebelum Belajar', 'Belajar',
   'رَبِّ زِدْنِي عِلْمًا وَارْزُقْنِي فَهْمًا',
   'Rabbi zidnii ilman warzuqnii fahman',
   'Ya Rabb, tambahkanlah ilmuku dan berilah aku pemahaman.', 10),
  ('00000000-0000-0000-0000-000000000002', 'Doa Kedua Orang Tua', 'Keluarga',
   'رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَارْحَمْهُمَا',
   'Rabbighfir lii waliwaalidayya warhamhumaa',
   'Ya Rabb, ampunilah aku dan kedua orang tuaku, serta sayangilah mereka.', 20),
  ('00000000-0000-0000-0000-000000000003', 'Doa Sebelum Tidur', 'Harian',
   'بِاسْمِكَ اللَّهُمَّ أَحْيَا وَأَمُوتُ',
   'Bismikallaahumma ahyaa wa amuut',
   'Dengan nama-Mu ya Allah aku hidup dan aku mati.', 30),
  ('00000000-0000-0000-0000-000000000004', 'Doa Bangun Tidur', 'Harian',
   'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
   'Alhamdulillaahil ladzii ahyaanaa ba''da maa amaatanaa wa ilaihin nusyuur',
   'Segala puji bagi Allah yang menghidupkan kami setelah mematikan kami, dan kepada-Nya kami kembali.', 40)
ON CONFLICT (id) DO NOTHING;

-- Auto-cleanup expired sessions (run via cron or pg_cron)
-- DELETE FROM sessions WHERE expires_at < NOW();

COMMIT;
