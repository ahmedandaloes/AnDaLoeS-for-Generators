-- QA finding: the completion trigger did not clamp commission to price_total
-- (unlike Dart projectCommission), so a misconfigured fixed fee > rental total
-- could store commission_amount > price_total → negative owner net. Clamp it.
CREATE OR REPLACE FUNCTION handle_rental_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_config  commission_config%ROWTYPE;
  v_amount  numeric;
BEGIN
  IF NEW.status <> 'completed' OR OLD.status = 'completed' THEN
    RETURN NEW;
  END IF;

  INSERT INTO payments (rental_request_id, amount, gateway, status)
  VALUES (NEW.id, NEW.price_total, 'cash', 'paid')
  ON CONFLICT DO NOTHING;

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
    -- Clamp to [0, price_total] so owner net is never negative.
    v_amount := LEAST(GREATEST(v_amount, 0), NEW.price_total);

    INSERT INTO commissions (
      rental_request_id, rental_amount, type, value, commission_amount, status
    ) VALUES (
      NEW.id, NEW.price_total, v_config.type, v_config.value, v_amount, 'accrued'
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;
