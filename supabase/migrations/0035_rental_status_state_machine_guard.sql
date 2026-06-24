-- Rental request status state-machine guard
-- Valid transitions:
--   pending  → accepted | rejected | cancelled
--   accepted → active   | cancelled
--   active   → completed
--   rejected, completed, cancelled → (terminal)

CREATE OR REPLACE FUNCTION check_rental_status_transition()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- No change — allow
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  IF OLD.status = 'pending' AND NEW.status IN ('accepted', 'rejected', 'cancelled') THEN
    RETURN NEW;
  END IF;
  IF OLD.status = 'accepted' AND NEW.status IN ('active', 'cancelled') THEN
    RETURN NEW;
  END IF;
  IF OLD.status = 'active' AND NEW.status = 'completed' THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION
    'Invalid rental status transition: % → %', OLD.status, NEW.status
    USING ERRCODE = 'P0001';
END;
$$;

DROP TRIGGER IF EXISTS rental_status_state_machine ON rental_requests;

CREATE TRIGGER rental_status_state_machine
  BEFORE UPDATE OF status ON rental_requests
  FOR EACH ROW EXECUTE FUNCTION check_rental_status_transition();
