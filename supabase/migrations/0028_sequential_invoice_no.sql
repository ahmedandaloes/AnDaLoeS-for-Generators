-- Tax readiness: invoices need a sequential, immutable number (ETA). The current
-- INV-XXXX is derived from the rental UUID (not sequential). Assign a real
-- sequential invoice number once, when a rental is completed.

CREATE SEQUENCE IF NOT EXISTS invoice_seq START 1001;

ALTER TABLE rental_requests ADD COLUMN IF NOT EXISTS invoice_no bigint;

-- BEFORE-update: stamp a sequential number the first time a rental completes.
CREATE OR REPLACE FUNCTION assign_invoice_no()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'completed'
     AND OLD.status IS DISTINCT FROM 'completed'
     AND NEW.invoice_no IS NULL THEN
    NEW.invoice_no := nextval('invoice_seq');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_invoice_no ON rental_requests;
CREATE TRIGGER trg_assign_invoice_no
  BEFORE UPDATE OF status ON rental_requests
  FOR EACH ROW EXECUTE FUNCTION assign_invoice_no();
