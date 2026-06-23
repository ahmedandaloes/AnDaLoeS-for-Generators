-- Add cached rating columns to generators table
ALTER TABLE generators
  ADD COLUMN IF NOT EXISTS avg_score numeric(3,1) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_count integer DEFAULT 0;

-- Backfill existing ratings
UPDATE generators g
SET
  avg_score = COALESCE((
    SELECT ROUND(AVG(r.score)::numeric, 1)
    FROM ratings r
    JOIN rental_requests rr ON r.rental_request_id = rr.id
    WHERE rr.generator_id = g.id
  ), 0),
  rating_count = COALESCE((
    SELECT COUNT(*)
    FROM ratings r
    JOIN rental_requests rr ON r.rental_request_id = rr.id
    WHERE rr.generator_id = g.id
  ), 0);

-- Function: recompute rating cache on new rating
CREATE OR REPLACE FUNCTION update_generator_rating_cache()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  gen_id uuid;
BEGIN
  SELECT rr.generator_id INTO gen_id
  FROM rental_requests rr
  WHERE rr.id = NEW.rental_request_id;

  UPDATE generators
  SET
    avg_score = COALESCE((
      SELECT ROUND(AVG(r.score)::numeric, 1)
      FROM ratings r
      JOIN rental_requests rr ON r.rental_request_id = rr.id
      WHERE rr.generator_id = gen_id
    ), 0),
    rating_count = COALESCE((
      SELECT COUNT(*)
      FROM ratings r
      JOIN rental_requests rr ON r.rental_request_id = rr.id
      WHERE rr.generator_id = gen_id
    ), 0)
  WHERE id = gen_id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_rating_inserted
  AFTER INSERT ON ratings
  FOR EACH ROW EXECUTE FUNCTION update_generator_rating_cache();
