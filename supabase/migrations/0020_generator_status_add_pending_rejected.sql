-- Fix: admin Generators tab crashed with
--   "invalid input value for enum generator_status: pending"
--
-- The admin generators tab (admin_generators_tab.dart) is built around a
-- moderation vocabulary: pending / available / unavailable / rejected. It both
-- filters on those values (.inFilter) and sets them (approve -> available,
-- reject -> rejected, take-down -> unavailable). But the generator_status enum
-- only had `available` and `unavailable`, so every load of that tab — and any
-- attempt to reject a listing — threw and failed.
--
-- This adds the two missing values so the existing admin moderation UI works
-- and admins can reject/take down bad listings.
--
-- NOTE: new generators still default to `available` (set in add_generator).
-- Flipping to a `pending`-by-default approval gate is a separate product
-- decision (needs active moderation) — tracked in GOAL.md for product-strategy.

ALTER TYPE generator_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE generator_status ADD VALUE IF NOT EXISTS 'rejected';
