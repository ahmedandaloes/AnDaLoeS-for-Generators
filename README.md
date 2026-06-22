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
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — phased plan. **Phase 1 MVP = core
  rental loop.**

## Where to start

Read `ROADMAP.md` → Phase 1. The MVP is the core rental loop: phone login →
browse generators → request rental → owner accepts. No online payment yet
(added in Phase 2).
