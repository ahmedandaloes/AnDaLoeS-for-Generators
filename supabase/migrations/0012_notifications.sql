-- In-app notifications: status changes notify the customer; new requests notify the owner.

CREATE TABLE IF NOT EXISTS notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type       text NOT NULL,
  title      text NOT NULL,
  body       text,
  data       jsonb DEFAULT '{}',
  is_read    boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_created
  ON notifications (user_id, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_own" ON notifications
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── Notify customer on rental status change ───────────────────────────────────
CREATE OR REPLACE FUNCTION notify_customer_on_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = OLD.status THEN RETURN NEW; END IF;

  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (
    NEW.customer_id,
    'rental_status',
    CASE NEW.status
      WHEN 'accepted'  THEN 'Rental request accepted!'
      WHEN 'rejected'  THEN 'Rental request rejected'
      WHEN 'active'    THEN 'Generator is now active'
      WHEN 'completed' THEN 'Rental completed'
      WHEN 'cancelled' THEN 'Rental cancelled'
      ELSE 'Rental update'
    END,
    CASE NEW.status
      WHEN 'accepted'  THEN 'Your request was accepted. The owner will deliver the generator.'
      WHEN 'rejected'  THEN 'Your rental request was not accepted this time.'
      WHEN 'active'    THEN 'The generator is with you. Enjoy!'
      WHEN 'completed' THEN 'Rental ended. Leave a review to help others.'
      WHEN 'cancelled' THEN 'This rental was cancelled.'
      ELSE NULL
    END,
    jsonb_build_object('rental_request_id', NEW.id, 'status', NEW.status)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_rental_status_change ON rental_requests;
CREATE TRIGGER on_rental_status_change
  AFTER UPDATE OF status ON rental_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_customer_on_status_change();

-- ── Notify owner on new rental request ────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_owner_on_new_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, body, data)
  SELECT
    c.owner_user_id,
    'new_request',
    'New rental request!',
    'You have a new request for ' || g.title || '.',
    jsonb_build_object('rental_request_id', NEW.id, 'generator_id', NEW.generator_id)
  FROM generators g
  JOIN companies c ON g.company_id = c.id
  WHERE g.id = NEW.generator_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_rental_request ON rental_requests;
CREATE TRIGGER on_new_rental_request
  AFTER INSERT ON rental_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_owner_on_new_request();
