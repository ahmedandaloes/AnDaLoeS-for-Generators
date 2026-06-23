-- Revenue controls (owner priority: "our money"). The commission ledger model:
-- commission accrues per completed rental (handle_rental_completion trigger),
-- admin tracks it and marks it settled as it's collected. Works in a cash
-- market with no payment gateway; online auto-collect can come later.
--
-- Admin needs to (a) mark commissions settled, and (b) set the commission rate
-- from the app. Neither was permitted by RLS.

-- Admin can update commission rows (e.g. accrued -> settled). Rows are still
-- created only by the SECURITY DEFINER trigger; admins don't insert/delete them.
DROP POLICY IF EXISTS commissions_update_admin ON commissions;
CREATE POLICY commissions_update_admin
  ON commissions FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Admin can manage the commission rate (insert new active config / deactivate old).
DROP POLICY IF EXISTS commission_config_write_admin ON commission_config;
CREATE POLICY commission_config_write_admin
  ON commission_config FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());
