# Roadmap

**Target: a complete generator-rental marketplace — not a minimal MVP.**

v1 is the full product: phone-OTP auth, browsing & search, the rental loop,
owner onboarding & dashboard, company verification, automatic commissions,
ratings, and an admin panel. Built properly the first time. See
`REQUIREMENTS.md` for the founder decisions behind this.

> **One deliberate exception:** **online payment is deferred.** At launch every
> rental is **cash on delivery** (owner collects cash, app records it). The
> schema already supports Paymob/Fawry, so turning payments on later needs no
> rework. This is the only feature pulled out of v1 — by choice.

> Building everything still needs an *order* — you can't write all features at
> once. The sequence below is about dependencies (auth before rentals, schema
> before UI), **not** about cutting scope.

---

## Workstream 0 — Foundations

- [ ] Flutter project with feature-first structure (see `ARCHITECTURE.md`).
- [ ] Riverpod, go_router, Supabase client, intl, Google Maps, FCM.
- [ ] **Localization: Arabic + English** with a language switch (Arabic RTL).
- [ ] Shared theme, design system, reusable widgets.
- [ ] Supabase project; full schema from `DATA_MODEL.md` + RLS policies.
- [ ] CI: format, analyze, test on every push.

## Workstream 1 — Identity & accounts

- [ ] Phone number + OTP login/registration — **open signup, no customer
      verification**.
- [ ] Profile management; a user can be **customer and/or owner**.
- [ ] Role-aware navigation (customer view vs owner view).

## Workstream 2 — Generators & discovery

- [ ] Generator listings: list + detail with photos.
- [ ] **Nationwide search & filter** by governorate/city, capacity (KVA),
      price, availability.
- [ ] Map view with location & distance (Google Maps).

## Workstream 3 — Rental loop (cash on delivery)

- [ ] Rental request: pick dates → **price from day/week/month rates
      (1 day = 8 operating hours)** → submit.
- [ ] Status lifecycle: pending → accepted → active → completed / rejected /
      cancelled.
- [ ] Owner accepts/rejects; owner delivers & operates the unit; customer
      tracks status.
- [ ] Record **cash** payment on completion (`payments.gateway = cash`).
- [ ] **Commissions:** auto-create a commission row when a rental is
      `completed`, using the active `commission_config` (fixed amount to start).
- [ ] Push notifications (FCM) on every status change.

## Workstream 4 — Online payments (deferred — later phase)

> Not in v1. Add when you're ready to move off cash-only.

- [ ] Paymob integration (cards + mobile wallets).
- [ ] Fawry integration (cash / kiosk).
- [ ] `payments` rows written by Edge Functions (service role only).
- [ ] Optional deposit / partial-payment handling.

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

Foundations → Identity → Generators → Rental loop (cash) → Owner platform &
verification → Trust & admin → (later) Online payments → Scale.

This is dependency order, not a scope cut. Each workstream is demoable when
done, so progress stays visible while we build toward the complete product.
