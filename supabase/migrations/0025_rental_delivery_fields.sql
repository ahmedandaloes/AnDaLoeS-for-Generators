-- Readiness (audit M2): delivery address + preferred time were concatenated into
-- the free-text `note`, so owners couldn't reliably parse where/when to deliver.
-- Promote them to structured columns. `note` reverts to a clean customer note.
-- Existing rows keep their combined note untouched (display falls back to note).

ALTER TABLE rental_requests ADD COLUMN IF NOT EXISTS delivery_address text;
ALTER TABLE rental_requests ADD COLUMN IF NOT EXISTS delivery_time text;
