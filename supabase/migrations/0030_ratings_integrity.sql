-- Role separation / trust hardening: ratings could be inserted by anyone for any
-- rental (only rater_id = auth.uid() was checked) — a rating-manipulation hole.
-- Restrict to an actual party (customer or owning owner) of a COMPLETED rental,
-- and enforce one rating per rater per rental.

DROP POLICY IF EXISTS ratings_insert_own ON ratings;
CREATE POLICY ratings_insert_own
  ON ratings FOR INSERT
  WITH CHECK (
    auth.uid() = rater_id
    AND EXISTS (
      SELECT 1 FROM rental_requests rr
      WHERE rr.id = ratings.rental_request_id
        AND rr.status = 'completed'
        AND (rr.customer_id = auth.uid() OR owns_company(rr.company_id))
    )
  );

CREATE UNIQUE INDEX IF NOT EXISTS ratings_unique_rater_rental
  ON ratings (rental_request_id, rater_id);
