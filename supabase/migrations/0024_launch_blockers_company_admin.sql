-- Launch blockers (readiness audit 2026-06-24): the marketplace could not
-- function end-to-end. Two DB-layer fixes close the owner→approve→list→book loop.
--
-- C1: company onboarding inserts `description`, but companies had no such column
--     → every owner's "create company" failed with a raw PostgREST error.
--
-- C2: the only UPDATE policy on companies/generators was owner-scoped, so the
--     admin panel's "Approve company" and generator moderation were silently
--     rejected by RLS (0 rows). Companies stayed `pending` forever and, since
--     public generator visibility requires an approved company, the customer
--     catalog was permanently empty. (SELECT already allows is_admin(); an admin
--     profile already exists — so adding admin UPDATE closes the loop.)

ALTER TABLE companies ADD COLUMN IF NOT EXISTS description text;

DROP POLICY IF EXISTS companies_update_admin ON companies;
CREATE POLICY companies_update_admin
  ON companies FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS generators_update_admin ON generators;
CREATE POLICY generators_update_admin
  ON generators FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());
