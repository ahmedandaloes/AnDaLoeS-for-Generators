-- Configurable customer tax (owner will confirm the real rate, e.g. 2% on
-- invoice). Admin-editable, mirrors commission_config. Default 14% VAT; the
-- owner can change rate/label and whether it applies always or only when the
-- customer requests an invoice.

CREATE TABLE IF NOT EXISTS tax_config (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rate         numeric NOT NULL DEFAULT 0.14,   -- 0.02 = 2%, 0.14 = 14%
  label        text    NOT NULL DEFAULT 'VAT',
  applies_when text    NOT NULL DEFAULT 'always', -- 'always' | 'on_invoice_request'
  active       boolean NOT NULL DEFAULT true,
  created_at   timestamptz DEFAULT now()
);

ALTER TABLE tax_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tax_config_select ON tax_config;
CREATE POLICY tax_config_select ON tax_config FOR SELECT USING (true);

DROP POLICY IF EXISTS tax_config_admin ON tax_config;
CREATE POLICY tax_config_admin ON tax_config FOR ALL
  USING (is_admin()) WITH CHECK (is_admin());

INSERT INTO tax_config (rate, label, applies_when, active)
SELECT 0.14, 'VAT', 'always', true
WHERE NOT EXISTS (SELECT 1 FROM tax_config WHERE active = true);
