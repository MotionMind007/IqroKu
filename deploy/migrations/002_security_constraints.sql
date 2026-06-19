DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'progress_status_check'
      AND conrelid = 'progress'::regclass
  ) THEN
    ALTER TABLE progress
      ADD CONSTRAINT progress_status_check
      CHECK (status IN ('notStarted', 'learning', 'fluent', 'review'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'progress_review_status_check'
      AND conrelid = 'progress'::regclass
  ) THEN
    ALTER TABLE progress
      ADD CONSTRAINT progress_review_status_check
      CHECK (review_status IN ('pending', 'approved', 'needs_repeat'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'attempts_assessment_status_check'
      AND conrelid = 'attempts'::regclass
  ) THEN
    ALTER TABLE attempts
      ADD CONSTRAINT attempts_assessment_status_check
      CHECK (assessment_status IN ('recorded', 'assessing', 'fluent', 'needsReview'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'attempts_review_status_check'
      AND conrelid = 'attempts'::regclass
  ) THEN
    ALTER TABLE attempts
      ADD CONSTRAINT attempts_review_status_check
      CHECK (review_status IN ('pending', 'approved', 'needs_repeat'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'attempts_status_check'
      AND conrelid = 'attempts'::regclass
  ) THEN
    ALTER TABLE attempts
      ADD CONSTRAINT attempts_status_check
      CHECK (status IS NULL OR status IN ('notStarted', 'learning', 'fluent', 'review'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'attempts_reviewed_by_fkey'
      AND conrelid = 'attempts'::regclass
  ) THEN
    ALTER TABLE attempts
      ADD CONSTRAINT attempts_reviewed_by_fkey
      FOREIGN KEY (reviewed_by) REFERENCES parents(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'progress_reviewed_by_fkey'
      AND conrelid = 'progress'::regclass
  ) THEN
    ALTER TABLE progress
      ADD CONSTRAINT progress_reviewed_by_fkey
      FOREIGN KEY (reviewed_by) REFERENCES parents(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'auth_tokens_purpose_check'
      AND conrelid = 'auth_tokens'::regclass
  ) THEN
    ALTER TABLE auth_tokens
      ADD CONSTRAINT auth_tokens_purpose_check
      CHECK (purpose IN ('email_verification', 'password_reset'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'notifications_user_type_check'
      AND conrelid = 'notifications'::regclass
  ) THEN
    ALTER TABLE notifications
      ADD CONSTRAINT notifications_user_type_check
      CHECK (user_type IN ('parent', 'child'));
  END IF;
END $$;
