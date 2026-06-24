-- Adds resolution metadata to reports for the admin adjudication flow.
ALTER TABLE reports
  ADD COLUMN IF NOT EXISTS resolution_note text,
  ADD COLUMN IF NOT EXISTS resolved_by     uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS resolved_at     timestamptz;

-- Trigger: when a report is resolved/dismissed, stamp resolved_at and resolved_by.
CREATE OR REPLACE FUNCTION stamp_report_resolution()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status IN ('resolved', 'dismissed')
     AND OLD.status NOT IN ('resolved', 'dismissed') THEN
    NEW.resolved_at := now();
    NEW.resolved_by := auth.uid();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS report_resolution_stamp ON reports;
CREATE TRIGGER report_resolution_stamp
  BEFORE UPDATE OF status ON reports
  FOR EACH ROW EXECUTE FUNCTION stamp_report_resolution();

-- Trigger: notify the reporter when their report is resolved or dismissed.
CREATE OR REPLACE FUNCTION notify_report_resolution()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _title text;
  _body  text;
BEGIN
  IF NEW.status IN ('resolved', 'dismissed')
     AND OLD.status NOT IN ('resolved', 'dismissed') THEN
    _title := CASE NEW.status
      WHEN 'resolved'  THEN 'Report resolved'
      ELSE                  'Report dismissed'
    END;
    _body := COALESCE(NEW.resolution_note, 'Your report has been reviewed by our team.');
    INSERT INTO notifications (user_id, type, title, body, rental_request_id)
    VALUES (NEW.reporter_id, 'report_resolved', _title, _body, NEW.rental_request_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS report_resolution_notify ON reports;
CREATE TRIGGER report_resolution_notify
  AFTER UPDATE OF status ON reports
  FOR EACH ROW EXECUTE FUNCTION notify_report_resolution();
