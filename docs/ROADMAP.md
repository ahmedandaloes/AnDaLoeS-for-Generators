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

- [x] Flutter project with feature-first structure (see `ARCHITECTURE.md`).
- [x] Riverpod, go_router, Supabase client, intl.
- [ ] Google Maps, FCM — deferred to later phase.
- [x] **Localization: Arabic + English** with a language switch (Arabic RTL).
- [x] Shared theme, design system, reusable widgets (Material 3, polished UI).
- [x] Supabase project; full schema from `DATA_MODEL.md` + RLS policies.
- [x] CI: format, analyze, test on every push (GitHub Actions, `.github/workflows/flutter.yml`).

## Workstream 1 — Identity & accounts

- [x] Phone number + OTP login/registration screen (SMS gateway to configure).
- [x] Email dev-login as fallback.
- [x] Profile screen: avatar, email/phone display, language switch, sign out.
- [x] Role-aware navigation: My Rentals (customer) + Owner Dashboard links in profile.

## Workstream 2 — Generators & discovery

- [x] Generator listings: scrollable list with polished cards.
- [x] Generator detail screen: photos carousel, pricing table, company info, Rent Now CTA.
- [x] **Search & filter** by title/city (search bar) + governorate + max KVA (filter sheet).
- [ ] Map view with location & distance (Google Maps) — next phase.

## Workstream 3 — Rental loop (cash on delivery)

- [x] Rental request screen: date range picker, best-price calculation (day/week/month), notes, submit.
- [x] Status lifecycle: pending → accepted → active → completed / rejected / cancelled.
- [x] Customer: My Rentals screen — list, status chips, cancel pending requests.
- [x] Owner: accept/reject/start/complete rental requests in Owner Dashboard.
- [x] Record cash payment row on completion (via Postgres trigger `on_rental_completed`).
- [x] **Commissions:** auto-create commission row when rental completed (trigger + `commission_config` table).
- [ ] Push notifications (FCM) on status change.

## Workstream 4 — Online payments (deferred — later phase)

> Not in v1. Add when you're ready to move off cash-only.

- [ ] Paymob integration (cards + mobile wallets).
- [ ] Fawry integration (cash / kiosk).
- [ ] `payments` rows written by Edge Functions (service role only).
- [ ] Optional deposit / partial-payment handling.

## Workstream 5 — Owner platform & onboarding (with verification)

- [x] Open onboarding: any user can register a company via Company Onboarding screen.
- [x] Company sign-up: name, contact phone, city/governorate → submitted as `pending`.
- [x] **Verification gate:** pending companies shown a "under review" message; generators hidden until approved.
- [ ] Document upload (commercial register, tax card, national ID) — needs Storage bucket.
- [ ] **Admin review UI** — see Workstream 6.
- [x] Owner dashboard: add generators, set prices, toggle availability.
- [x] Incoming-request management: accept, reject, start, complete.
- [x] Owner earnings view (rentals, commissions taken, net payout).

## Workstream 6 — Trust & quality

- [x] Ratings & reviews (customer ↔ owner): star rating + comment, unique per rental, RLS-protected.
- [x] Basic dispute / report flow (ReportScreen with 6 reasons, admin Reviews tab, RLS-protected `reports` table).
- [x] Admin panel for the platform (you): company approvals, users, generators, rentals, commission stats.

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
