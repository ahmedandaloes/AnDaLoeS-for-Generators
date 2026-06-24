-- QA finding: pricing treats end_date as the RETURN day (days = end - start,
-- exclusive end), but the no-overlap constraint blocked [start, end] inclusive —
-- so a rental ending the 8th wrongly blocked the next customer from starting the
-- 8th. Standardize on end_date = return day → rental occupies [start, end).
-- Loosening ']' -> ')' can only reduce conflicts, so existing rows stay valid.
ALTER TABLE rental_requests DROP CONSTRAINT IF EXISTS rental_requests_no_overlap;
ALTER TABLE rental_requests
  ADD CONSTRAINT rental_requests_no_overlap
  EXCLUDE USING gist (
    generator_id WITH =,
    daterange(start_date, end_date, '[)') WITH &&
  )
  WHERE (status IN ('accepted', 'active'));
