-- B2B repositioning (see docs/BUSINESS_STRATEGY.md): tag each generator with the
-- use-case segments it serves, so customers can browse by need and the
-- marketplace can lead with the durable B2B segments (events, construction,
-- industrial, telecom, agriculture) rather than consumer outage-backup.
--
-- text[] (multi-valued): a single unit can serve several segments. Filtered in
-- the app with array overlap (&&). Defaults to empty so existing rows are valid.

ALTER TABLE generators
  ADD COLUMN IF NOT EXISTS use_cases text[] NOT NULL DEFAULT '{}';

-- GiST index for fast array-overlap filtering as listings grow.
CREATE INDEX IF NOT EXISTS generators_use_cases_idx
  ON generators USING gin (use_cases);
