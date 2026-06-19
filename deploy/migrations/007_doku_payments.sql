BEGIN;

CREATE TABLE IF NOT EXISTS payment_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  provider VARCHAR(20) NOT NULL DEFAULT 'doku'
    CHECK (provider IN ('doku')),
  invoice_number VARCHAR(120) NOT NULL UNIQUE,
  request_id VARCHAR(128) NOT NULL UNIQUE,
  plan VARCHAR(50) NOT NULL DEFAULT 'plus',
  amount INTEGER NOT NULL CHECK (amount > 0),
  currency CHAR(3) NOT NULL DEFAULT 'IDR',
  status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'paid', 'failed', 'expired', 'cancelled')),
  checkout_url TEXT,
  provider_order_id TEXT,
  raw_response JSONB,
  paid_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_orders_parent
  ON payment_orders(parent_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payment_orders_status
  ON payment_orders(status, created_at DESC);

CREATE TABLE IF NOT EXISTS payment_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider VARCHAR(20) NOT NULL DEFAULT 'doku'
    CHECK (provider IN ('doku')),
  request_id VARCHAR(128) NOT NULL,
  invoice_number VARCHAR(120),
  event_type VARCHAR(80),
  signature_valid BOOLEAN NOT NULL DEFAULT FALSE,
  payload JSONB NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (provider, request_id)
);

CREATE INDEX IF NOT EXISTS idx_payment_events_invoice
  ON payment_events(provider, invoice_number, received_at DESC);

COMMIT;
