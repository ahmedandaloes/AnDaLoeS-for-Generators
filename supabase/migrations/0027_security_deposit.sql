-- Trust layer foundation: a refundable security deposit per generator. Recorded
-- now (shown at booking, stored on the request); actual holding/release comes
-- with escrow later. Defaults to 0 so existing rows are valid.

ALTER TABLE generators
  ADD COLUMN IF NOT EXISTS deposit_amount numeric NOT NULL DEFAULT 0;

ALTER TABLE rental_requests
  ADD COLUMN IF NOT EXISTS deposit_amount numeric NOT NULL DEFAULT 0;
