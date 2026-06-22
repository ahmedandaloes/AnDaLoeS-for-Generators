# Roadmap

**Target: a complete generator-rental marketplace — not a minimal MVP.**

The goal of v1 is the full product: phone-OTP auth, browsing, the rental loop,
**online payments (Paymob + Fawry)**, owner onboarding & dashboard, automatic
commissions, ratings, and search. We build it properly the first time.

> Building everything still needs an *order* — you can't write all features at
> once. The order below is about dependencies (auth before payments, schema
> before UI), **not** about cutting scope. Every item is in scope for v1.

---

## Workstream 0 — Foundations

- [ ] Flutter project with feature-first structure (see `ARCHITECTURE.md`).
- [ ] Riverpod, go_router, Supabase client, intl, Google Maps, FCM.
- [ ] Arabic-first localization (ar + en, full RTL).
- [ ] Shared theme, design system, reusable widgets.
- [ ] Supabase project; full schema from `DATA_MODEL.md` + RLS policies.
- [ ] CI: format, analyze, test on every push.

## Workstream 1 — Identity & accounts

- [ ] Phone number + OTP login/registration.
- [ ] Profile management; a user can be **customer and/or owner**.
- [ ] Role-aware navigation (customer view vs owner view).

## Workstream 2 — Generators & discovery

- [ ] Generator listings: list + detail with photos.
- [ ] Search & filter by city, capacity (KVA), price, availability.
- [ ] Map view with location & distance (Google Maps).

## Workstream 3 — Rental loop

- [ ] Rental request: pick dates → price calculation → submit.
- [ ] Status lifecycle: pending → accepted → active → completed / rejected /
      cancelled.
- [ ] Owner accepts/rejects; customer tracks status.
- [ ] Push notifications (FCM) on every status change.

## Workstream 4 — Payments & money (in v1, not deferred)

- [ ] Paymob integration (cards + mobile wallets).
- [ ] Fawry integration (cash / kiosk).
- [ ] `payments` rows written by Edge Functions (service role only).
- [ ] **Commissions:** auto-create a commission record when a rental is
      `completed`; track accrued vs settled.

## Workstream 5 — Owner platform & onboarding (with verification)

- [ ] Open onboarding so **any** company can apply to join (not only family).
- [ ] Company sign-up: create company account, upload verification documents
      (commercial register, tax card, national ID) to a private bucket.
- [ ] **Verification gate:** new companies start `pending`; their generators
      stay hidden from customers until an admin approves.
- [ ] **Admin review:** you approve / reject companies (with a reason), from the
      admin panel — see Workstream 6.
- [ ] Owner dashboard: add/manage generators, prices, availability.
- [ ] Owner earnings view (rentals, commissions taken, net payout).
- [ ] Incoming-request management.

## Workstream 6 — Trust & quality

- [ ] Ratings & reviews (customer ↔ owner).
- [ ] Basic dispute / report flow.
- [ ] Admin panel for the platform (you): users, generators, payouts,
      analytics.

## Workstream 7 — Scale & operations

- [ ] Move complex pricing/payout/commission logic into a dedicated backend
      (Supabase Edge Functions → NestJS) as rules grow.
- [ ] Caching, monitoring, read replicas as load grows.
- [ ] Fraud / abuse checks.

---

## Suggested build sequence

Foundations → Identity → Generators → Rental loop → Payments → Owner platform
→ Trust → Scale.

This is dependency order, not a scope cut. Each workstream is demoable when
done, so progress stays visible while we build toward the complete product.
