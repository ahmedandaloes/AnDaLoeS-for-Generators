-- Auto-notify customer when owner changes rental request status
CREATE OR REPLACE FUNCTION notify_rental_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  gen_title TEXT;
BEGIN
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT title INTO gen_title
    FROM generators WHERE id = NEW.generator_id;

  CASE NEW.status
    WHEN 'accepted' THEN
      INSERT INTO notifications(user_id, type, title, body, rental_request_id)
      VALUES (
        NEW.customer_id, 'request_accepted',
        'Request accepted ✅',
        'Your request for "' || COALESCE(gen_title, 'the generator') || '" was accepted.',
        NEW.id
      );
    WHEN 'rejected' THEN
      INSERT INTO notifications(user_id, type, title, body, rental_request_id)
      VALUES (
        NEW.customer_id, 'request_rejected',
        'Request rejected',
        'Your request for "' || COALESCE(gen_title, 'the generator') || '" was not accepted.',
        NEW.id
      );
    WHEN 'active' THEN
      INSERT INTO notifications(user_id, type, title, body, rental_request_id)
      VALUES (
        NEW.customer_id, 'rental_started',
        'Rental started 🚀',
        'Your rental of "' || COALESCE(gen_title, 'the generator') || '" is now active.',
        NEW.id
      );
    WHEN 'completed' THEN
      INSERT INTO notifications(user_id, type, title, body, rental_request_id)
      VALUES (
        NEW.customer_id, 'rental_completed',
        'Rental completed',
        '"' || COALESCE(gen_title, 'Your generator rental') || '" has been completed. Please leave a review!',
        NEW.id
      );
    ELSE NULL;
  END CASE;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_rental_status_notifications ON rental_requests;
CREATE TRIGGER trg_rental_status_notifications
  AFTER UPDATE OF status ON rental_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_rental_status_change();
