-- Money-model shift (see docs/MONETIZATION.md): replace the flat 50 EGP per
-- completed rental with a 10% commission charged to the owner.
--
-- Rationale: on a typical ~EGP 5,000 rental, 50 EGP is ~3.6% — far below the
-- 10–15% defensible band for high-value physical rentals, and it doesn't scale
-- with deal value. Launch at 10% (Phase 1); raise toward 12–15% once trust
-- features (deposit, insurance, verification) ship.
--
-- The handle_rental_completion trigger already computes `percentage` as
-- price_total * value, so value 0.10 = 10%. We deactivate the old fixed row and
-- insert a new active percentage row (preserves the rate-history audit trail).

UPDATE commission_config
  SET active = false
  WHERE active = true AND company_id IS NULL;

INSERT INTO commission_config (company_id, type, value, active)
  VALUES (NULL, 'percentage', 0.10, true);
