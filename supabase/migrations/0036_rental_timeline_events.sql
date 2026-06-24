-- Fulfillment timeline events for rental requests
-- Tracks every meaningful status transition with a timestamp and optional note.
-- Events are append-only (no updates/deletes by app users).

CREATE TABLE IF NOT EXISTS rental_timeline_events (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rental_id     uuid NOT NULL REFERENCES rental_requests(id) ON DELETE CASCADE,
  event         text NOT NULL,  -- accepted|preparing|en_route|delivered|active|completed|cancelled|rejected
  note          text,
  actor_id      uuid REFERENCES auth.users(id),
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_timeline_rental_id ON rental_timeline_events(rental_id, created_at);

ALTER TABLE rental_timeline_events ENABLE ROW LEVEL SECURITY;

-- Owner (company) can insert events for their rentals
CREATE POLICY timeline_insert_owner
  ON rental_timeline_events FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM rental_requests rr
      JOIN companies c ON c.id = rr.company_id
      WHERE rr.id = rental_id
        AND c.owner_user_id = auth.uid()
    )
  );

-- Both parties can read timeline of their own rental
CREATE POLICY timeline_select_parties
  ON rental_timeline_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM rental_requests rr
      JOIN companies c ON c.id = rr.company_id
      WHERE rr.id = rental_id
        AND (rr.customer_id = auth.uid() OR c.owner_user_id = auth.uid())
    )
  );

-- Admins can read and insert everything
CREATE POLICY timeline_admin_all
  ON rental_timeline_events FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Auto-insert a timeline event whenever rental_requests.status changes.
CREATE OR REPLACE FUNCTION record_rental_timeline_event()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO rental_timeline_events (rental_id, event, actor_id)
    VALUES (NEW.id, NEW.status, auth.uid());
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rental_status_timeline ON rental_requests;

CREATE TRIGGER rental_status_timeline
  AFTER UPDATE OF status ON rental_requests
  FOR EACH ROW EXECUTE FUNCTION record_rental_timeline_event();
