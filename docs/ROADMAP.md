# Roadmap

Phased plan. **Phase 1 (the MVP) is the core rental loop only** — the fastest
path to getting your dad's generators rentable through the app. Payments and
the full marketplace come after.

---

## Phase 0 — Foundations (setup)

- [ ] Create Flutter project with feature-first structure (see `ARCHITECTURE.md`).
- [ ] Add Riverpod, go_router, Supabase Flutter client, intl.
- [ ] Set up Arabic-first localization (ar + en, RTL).
- [ ] Create Supabase project; apply schema from `DATA_MODEL.md`.
- [ ] Configure phone OTP auth + an SMS provider.

## Phase 1 — MVP: core rental loop ⭐ (start here)

Goal: a customer can log in, browse the family generators, request a rental,
and the owner can accept it. **No online payment yet — settle in cash/manually.**

- [ ] **Auth:** phone number + OTP login.
- [ ] **Generators:** list view + detail view of available generators.
- [ ] **Rental request:** pick dates → see total price → submit request.
- [ ] **Owner side (minimal):** owner sees incoming requests, accepts/rejects.
- [ ] **Notifications:** FCM push on new request / status change.
- [ ] Seed the database with your dad's real generators.

**Definition of done:** a real customer rents a real generator through the
app, owner accepts, rental completes. Money handled offline for now.

## Phase 2 — Payments

- [ ] Create Paymob account (cards + wallets); integrate checkout.
- [ ] Add Fawry for cash/kiosk payments.
- [ ] Write `payments` and `commissions` rows via Edge Functions.
- [ ] Auto-create a commission record when a rental is `completed`.

## Phase 3 — Open the marketplace

- [ ] Owner onboarding flow (any owner can join, not just family).
- [ ] Full owner dashboard: manage generators, prices, availability, earnings.
- [ ] Ratings & reviews for trust.
- [ ] Search & filter by city, capacity (KVA), price.

## Phase 4 — Scale & operations

- [ ] Move pricing/payout/commission logic into a dedicated backend
      (Edge Functions → NestJS) as rules get complex.
- [ ] Admin panel for the platform (you): disputes, payouts, analytics.
- [ ] Performance: caching, read replicas, monitoring.
- [ ] Fraud / abuse checks.

---

## Suggested first build order (Phase 1 tasks)

1. Project skeleton + theme + localization.
2. Supabase auth (phone OTP) → working login screen.
3. Generators list + detail (read from Supabase).
4. Rental request flow (create row, compute price).
5. Owner request list + accept/reject.
6. Push notifications.

Each step is independently demoable — you always have something working.
