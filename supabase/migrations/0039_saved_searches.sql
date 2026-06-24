-- Stores named search filters per user so they can re-apply them later.
-- "New match alerts" (Step 2) will use a trigger on this table once
-- Edge Functions are enabled (Sprint 10).

CREATE TABLE IF NOT EXISTS saved_searches (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  filter      jsonb NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE saved_searches ENABLE ROW LEVEL SECURITY;

-- Each user can only see and modify their own saved searches.
CREATE POLICY saved_searches_owner
  ON saved_searches FOR ALL
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE INDEX idx_saved_searches_user ON saved_searches(user_id);
