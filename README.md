# AnDaLoeS for Generators

A mobile marketplace for renting electrical **generators** in Egypt. Generator
owners list their units; customers request rentals; the platform earns a
commission on every completed rental.

**Stack:** Flutter (Android + iOS) · Riverpod · Supabase (Postgres) ·
Paymob/Fawry payments · phone OTP auth · Arabic-first (RTL).

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — stack choices, Egypt-specific
  decisions, and the feature-first project structure.
- [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) — database schema, relationships,
  and security (RLS) design.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — plan to build the **full
  marketplace** (not a minimal MVP), organized into workstreams.

## Scope

v1 is the complete product: phone-OTP auth, browsing & search, the rental
loop, **online payments (Paymob + Fawry)**, owner onboarding & dashboard,
automatic commissions, and ratings. The roadmap orders the work by dependency,
not by cutting features. Start with `ROADMAP.md` → Workstream 0 (Foundations).
