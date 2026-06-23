-- Persists generator saves/bookmarks per user.
-- Simple join table: (user_id, generator_id) unique pair.

CREATE TABLE IF NOT EXISTS user_favorites (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  generator_id uuid NOT NULL REFERENCES generators(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now(),
  UNIQUE (user_id, generator_id)
);

ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;

-- Users can only see and manage their own favorites.
CREATE POLICY "favorites_own" ON user_favorites
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
