-- Chat messages: one thread per rental_request, between customer and owner
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rental_request_id UUID NOT NULL REFERENCES rental_requests(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  body TEXT NOT NULL CHECK (char_length(body) <= 500),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS messages_rental_request_id_idx
  ON messages(rental_request_id, created_at);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Read: customer or owner of the rental request
CREATE POLICY "messages_read" ON messages FOR SELECT
  USING (
    rental_request_id IN (
      SELECT id FROM rental_requests
      WHERE customer_id = auth.uid()
         OR company_id IN (
           SELECT id FROM companies WHERE owner_user_id = auth.uid()
         )
    )
  );

-- Insert: only authenticated party of the rental, sender must be themselves
CREATE POLICY "messages_insert" ON messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND rental_request_id IN (
      SELECT id FROM rental_requests
      WHERE customer_id = auth.uid()
         OR company_id IN (
           SELECT id FROM companies WHERE owner_user_id = auth.uid()
         )
    )
  );
