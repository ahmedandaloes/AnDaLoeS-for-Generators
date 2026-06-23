-- Business rule: a generator cannot be committed to two overlapping rentals.
--
-- Until now overlap was only a soft UI warning (rental_request_screen
-- _checkConflicts) — two customers could both end up with `accepted` rentals on
-- the same generator for overlapping dates. This enforces it at the DB level.
--
-- Design: a PARTIAL exclusion constraint scoped to the committed statuses
-- (`accepted`, `active`). Because a new request is inserted as `pending`, the
-- constraint never blocks request submission. It bites at the moment an owner
-- ACCEPTS (pending -> accepted) or activates a request that overlaps an already
-- accepted/active one for the same generator — so the owner can never
-- double-commit a unit. pending/rejected/cancelled/completed are ignored.
--
-- Date ranges are inclusive on both ends ('[]') since start_date and end_date
-- are both rental days. Verified: zero existing overlaps, so the constraint
-- adds cleanly.

CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE rental_requests
  ADD CONSTRAINT rental_requests_no_overlap
  EXCLUDE USING gist (
    generator_id WITH =,
    daterange(start_date, end_date, '[]') WITH &&
  )
  WHERE (status IN ('accepted', 'active'));
