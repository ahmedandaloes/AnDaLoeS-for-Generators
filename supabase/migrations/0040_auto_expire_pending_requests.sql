-- Auto-cancel pending rental_requests older than 48 hours.
-- Runs via pg_cron (schedule in Supabase dashboard: every 1 hour).
-- The function is safe to call manually too.

CREATE OR REPLACE FUNCTION public.expire_stale_pending_requests()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  expired_count integer;
BEGIN
  UPDATE rental_requests
  SET status = 'cancelled'
  WHERE status = 'pending'
    AND created_at < NOW() - INTERVAL '48 hours';

  GET DIAGNOSTICS expired_count = ROW_COUNT;
  RETURN expired_count;
END;
$$;

-- Grant execute to authenticated (for manual admin trigger via RPC)
GRANT EXECUTE ON FUNCTION public.expire_stale_pending_requests() TO authenticated;

COMMENT ON FUNCTION public.expire_stale_pending_requests() IS
  'Cancel pending rental requests older than 48h. Schedule via pg_cron: SELECT cron.schedule(''expire-pending-hourly'', ''0 * * * *'', ''SELECT public.expire_stale_pending_requests()'');';
