-- Delivery handshake: owner marks a rental "out for delivery" before starting it,
-- giving customers visibility and capturing a delivery timestamp (feeds on-time
-- reliability). Owner-driven (the customer can't move status to active under RLS,
-- which would bypass owner acceptance) — so this stays a timestamp, not a status.
ALTER TABLE rental_requests ADD COLUMN IF NOT EXISTS delivered_at timestamptz;
