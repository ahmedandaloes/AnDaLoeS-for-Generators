-- Ratings: customer rates the rental experience, owner rates the customer.
-- One rating per (rental_request, rater) — enforced by unique constraint.

CREATE TABLE IF NOT EXISTS ratings (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rental_request_id uuid NOT NULL REFERENCES rental_requests(id) ON DELETE CASCADE,
  rater_id          uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  ratee_id          uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  score             smallint NOT NULL CHECK (score BETWEEN 1 AND 5),
  comment           text,
  created_at        timestamptz DEFAULT now(),
  UNIQUE (rental_request_id, rater_id)
);

ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

-- Anyone can read ratings
CREATE POLICY "ratings_read_all" ON ratings
  FOR SELECT USING (TRUE);

-- Only the rater can insert their own rating
CREATE POLICY "ratings_insert_own" ON ratings
  FOR INSERT WITH CHECK (auth.uid() = rater_id);

-- Rater can update their rating within 24h (optional nicety — skip for now)
-- CREATE POLICY ... (omitted for simplicity)
