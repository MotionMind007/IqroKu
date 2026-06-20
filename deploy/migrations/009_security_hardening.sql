ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS token_hash CHAR(64);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'sessions'
      AND column_name = 'token'
  ) THEN
    UPDATE sessions
    SET token_hash = encode(digest(token, 'sha256'), 'hex')
    WHERE token_hash IS NULL
      AND token IS NOT NULL;
  END IF;
END $$;

DELETE FROM sessions
WHERE token_hash IS NULL;

DO $$
DECLARE
  token_pk_name TEXT;
BEGIN
  SELECT tc.constraint_name
  INTO token_pk_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_schema = tc.constraint_schema
   AND kcu.constraint_name = tc.constraint_name
   AND kcu.table_name = tc.table_name
  WHERE tc.table_schema = 'public'
    AND tc.table_name = 'sessions'
    AND tc.constraint_type = 'PRIMARY KEY'
    AND kcu.column_name = 'token'
  LIMIT 1;

  IF token_pk_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE sessions DROP CONSTRAINT %I', token_pk_name);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'sessions'
      AND column_name = 'token'
  ) THEN
    ALTER TABLE sessions
      ALTER COLUMN token DROP NOT NULL;
  END IF;
END $$;

ALTER TABLE sessions
  ALTER COLUMN token_hash SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_token_hash
  ON sessions(token_hash);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'attempts_book_id_check'
      AND conrelid = 'attempts'::regclass
  ) THEN
    ALTER TABLE attempts
      ADD CONSTRAINT attempts_book_id_check
      CHECK (book_id BETWEEN 1 AND 99);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'attempts_page_number_check'
      AND conrelid = 'attempts'::regclass
  ) THEN
    ALTER TABLE attempts
      ADD CONSTRAINT attempts_page_number_check
      CHECK (page_number BETWEEN 1 AND 999);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'children_study_days_check'
      AND conrelid = 'children'::regclass
  ) THEN
    ALTER TABLE children
      ADD CONSTRAINT children_study_days_check
      CHECK (
        study_days IS NULL
        OR (
          array_length(study_days, 1) IS NOT NULL
          AND 1 <= ALL(study_days)
          AND 7 >= ALL(study_days)
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'children_repeat_progress_check'
      AND conrelid = 'children'::regclass
  ) THEN
    ALTER TABLE children
      ADD CONSTRAINT children_repeat_progress_check
      CHECK (
        repeat_from_page IS NULL
        OR repeat_from_book IS NULL
        OR (
          repeat_from_page BETWEEN 1 AND 999
          AND repeat_from_book BETWEEN 1 AND 99
        )
      );
  END IF;
END $$;
