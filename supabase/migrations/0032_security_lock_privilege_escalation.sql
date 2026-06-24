-- Security hardening (QA finding, 2026-06-24): RLS is the real authorization
-- boundary (client routes are only login-gated). Three privilege-escalation holes:
--  1) profiles_update_own let any user set their own role='admin'.
--  2) companies_update_own let an owner self-approve (verification_status).
--  3) customer cancel policy allowed cancelling accepted/active (not just pending).

-- 1) Lock role changes to admins only.
CREATE OR REPLACE FUNCTION public.lock_profile_role()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only an admin can change a user role';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_lock_profile_role ON public.profiles;
CREATE TRIGGER trg_lock_profile_role BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.lock_profile_role();

-- 2) Lock company verification fields to admins only (owners cannot self-approve).
CREATE OR REPLACE FUNCTION public.lock_company_verification()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() AND (
       NEW.verification_status IS DISTINCT FROM OLD.verification_status
    OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by
    OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at
  ) THEN
    RAISE EXCEPTION 'Only an admin can change company verification';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_lock_company_verification ON public.companies;
CREATE TRIGGER trg_lock_company_verification BEFORE UPDATE ON public.companies
  FOR EACH ROW EXECUTE FUNCTION public.lock_company_verification();

-- 3) Customer may only cancel a PENDING request (was: any of their requests).
DROP POLICY IF EXISTS rental_requests_update_customer ON public.rental_requests;
CREATE POLICY rental_requests_update_customer ON public.rental_requests
  FOR UPDATE
  USING (customer_id = auth.uid() AND status = 'pending')
  WITH CHECK (customer_id = auth.uid() AND status = 'cancelled');
