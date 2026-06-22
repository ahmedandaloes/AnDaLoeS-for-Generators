-- Default platform-wide commission: 50 EGP fixed per completed rental.
-- company_id = NULL means it applies to all companies.
-- Change the value here any time without touching code.

INSERT INTO commission_config (type, value, active, company_id)
VALUES ('fixed', 50, TRUE, NULL)
ON CONFLICT DO NOTHING;
