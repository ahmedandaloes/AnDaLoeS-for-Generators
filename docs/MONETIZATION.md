# Monetization & Payment Workflow — AnDaLoeS for Generators

> Derived from market research (2026-06-23). Defines the revenue model, the
> money flow through a rental, the phased rollout, and compliance. See
> `BUSINESS_STRATEGY.md` for the thesis and `../GOAL.md` for the backlog.

## 1. The Problem With Today's Model

Current: a **flat 50 EGP commission per completed rental**, created by the
`handle_rental_completion` DB trigger, settled cash-on-delivery.

Why it must change:
- On a typical ~EGP 5,000 ($100) rental, 50 EGP ≈ **3.6%** — far below the
  **10–15% defensible band** for high-value physical rentals. We leave money on
  the table and don't scale with deal value.
- In a cash market it is **trivially evadable** — parties settle offline and
  skip the fee.

## 2. Target Revenue Model

**Percentage commission charged to the owner, collected via digital escrow.**

- **Take rate band:** 10–15% is defensible (Airbnb converged ~15.5%). Rates
  above 15% require **bundled trust services** (insurance/deposits/verification)
  — Turo reaches 25–38% *only* because it bundles protection.
- **Phased rollout (avoid pushing price-sensitive owners off-platform):**
  - **Phase 1 (launch):** ~**8–10%** (or keep a low flat fee) while trust
    features are thin.
  - **Phase 2:** raise toward **12–15%** as deposit + damage protection + ID
    verification go live to justify it.
- The DB already supports this: `commission_config` has a `percentage` type and
  per-company override — switching from `fixed` to `percentage` is a config
  change, not a schema change.

## 3. Money Flow Through a Rental (target workflow)

```
browse → instant booking (calendar) → security DEPOSIT authorized
   → owner ACCEPTS → escrow collects (rent + deposit) to PLATFORM account
   → delivery → ACTIVE → COMPLETED
   → commission auto-deducted; OWNER paid out (rent − commission) ≤ 3 working days
   → deposit released (or claimed on damage) → both parties RATE
```

Key rules:
- **Commission & payment creation stay server-side** (DB trigger), never in the
  Flutter client.
- **Owner payout = rent − commission**, disbursed within the CBE-mandated
  **3 working days**.
- **Security deposit** is held at booking and released on clean completion, or
  claimed (partially/fully) on a damage report.

## 4. Payments in Egypt (how we collect)

Context *[fact]*: COD is still **~55%** of e-commerce but digital merchant
adoption went 12%→58% (2020→2024); wallets/InstaPay/Meeza are now mainstream.
Our segment (higher-value, repeat, semi-professional) is more digital-reachable
than mass retail.

**Approach:**
- **Digital escrow** via **Paymob** (2.75% + 3 EGP, mass-payout capable) or
  **Kashier** (payouts in 3 working days): gateway collects full rent to the
  platform account, then pays out the owner share minus commission.
- **For the COD segment:** route "cash" through **Fawry pay-against-code** so
  even cash customers pay *into* the platform at a kiosk — preserving commission
  capture without true hand-to-hand cash.
- **Nudge migration:** gate instant-booking / verified perks behind
  digital-payment use.

## 5. Anti-Leakage (protect the take rate)

Leakage rises with the take rate (cash deals skip the fee). Controls:
1. **Escrow auto-deduct** — commission removed before payout (can't be skipped on digital).
2. **Fawry cash-against-code** — captures "cash" into the platform.
3. **Low launch take rate** — evading 8–10% isn't worth the hassle.
4. **Detection** — flag off-platform patterns (early cancellations, contact-share
   in chat, geocluster repeat pairs).
5. **Penalties** — warnings/suspension for confirmed off-platform dealing.

## 6. Trust Layer (justifies the rate)

- **Security deposit** (held, released on clean return).
- **Damage protection / basic insurance** (highest-leverage lever — the reason
  Turo's take rate is high).
- **ID + equipment verification** (owners already go through company approval).
- **Reviews/ratings tied to real transactions** (already in app), in-platform
  payment, instant booking for verified users.

## 7. Compliance (CBE)

Holding rent funds makes the platform a **payment facilitator** under CBE
Payment Services rules:
- Funds received into an account in the platform's name → forwarded to owners
  **within ≤3 working days**.
- **Separate (escrow-style) account** for customer funds; bank guarantee ≈ 3
  daily collections; **all settlement in EGP**.
- **Early stage: operate *through* a licensed gateway** (Paymob/Kashier/Fawry)
  rather than holding a license. Get a compliance review against the **June 2025
  PSP/PSO licensing rules** before scaling escrow.

## 8. Sources
Take rates: lodgify, houst, Sacra (Turo), sharetribe, qoreups. Payments:
23hublab, transfi, ibsintelligence, businesstec. Gateways: paymob, inai, kashier.
Regulation: Lexology (CBE PSP), cbe.org.eg (June-2025 rules). Leakage: BU Platform
Strategy 2023. Trust: Towlos Protect+, sharetribe.

*Flags:* Kashier split-payment/sub-merchant capability unconfirmed publicly —
verify directly. CBE obligations foundational to 2019 — verify vs June-2025 rules.
