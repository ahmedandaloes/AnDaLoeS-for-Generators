ALTER TABLE generators
  ADD COLUMN IF NOT EXISTS hire_type text DEFAULT 'dry_hire',
  ADD COLUMN IF NOT EXISTS fuel_policy text DEFAULT 'customer_provides',
  ADD COLUMN IF NOT EXISTS accessories text[] DEFAULT '{}';
