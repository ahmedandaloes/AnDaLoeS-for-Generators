-- When a rental_request is marked 'completed', automatically:
--   1. Insert a cash payment row (gateway=cash, status=paid)
--   2. Look up the active commission_config and insert a commission row
-- Runs as a SECURITY DEFINER trigger so it can write to payments/commissions
-- even when the calling user only has UPDATE rights on rental_requests.

CREATE OR REPLACE FUNCTION handle_rental_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_config  commission_config%ROWTYPE;
  v_amount  numeric;
BEGIN
  -- Only fire on transition TO 'completed'
  IF NEW.status <> 'completed' OR OLD.status = 'completed' THEN
    RETURN NEW;
  END IF;

  -- 1. Record cash payment
  INSERT INTO payments (
    rental_request_id, amount, gateway, status
  ) VALUES (
    NEW.id, NEW.price_total, 'cash', 'paid'
  )
  ON CONFLICT DO NOTHING;

  -- 2. Find the most specific active commission_config:
  --    company-level override first, then platform-wide default.
  SELECT * INTO v_config
  FROM commission_config
  WHERE active = TRUE
    AND (company_id = NEW.company_id OR company_id IS NULL)
  ORDER BY company_id NULLS LAST
  LIMIT 1;

  IF FOUND THEN
    v_amount := CASE v_config.type
      WHEN 'fixed'      THEN v_config.value
      WHEN 'percentage' THEN NEW.price_total * v_config.value
      ELSE 0
    END;

    INSERT INTO commissions (
      rental_request_id,
      rental_amount,
      type,
      value,
      commission_amount,
      status
    ) VALUES (
      NEW.id,
      NEW.price_total,
      v_config.type,
      v_config.value,
      v_amount,
      'accrued'
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_rental_completed ON rental_requests;
CREATE TRIGGER on_rental_completed
  AFTER UPDATE ON rental_requests
  FOR EACH ROW
  EXECUTE FUNCTION handle_rental_completion();
