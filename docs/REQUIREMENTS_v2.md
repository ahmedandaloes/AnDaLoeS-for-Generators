# AnDaLoeS — Requirements v2.0 (authoritative)

> Source: owner's Business Requirements / Workflow & Technical Specification, Draft v2.0
> (discovery interview). This is the canonical product spec. The current build is
> mapped against it in [GAP_ANALYSIS.md](./GAP_ANALYSIS.md).

## Model (confirmed)
- **Marketplace**: owners list & maintain their own generators.
- **Owner delivers** and handles on-site handover (no platform fleet at launch).
- **Revenue**: % commission per booking.
- **Payments**: Cash on Delivery at launch; Egyptian online methods Phase 2.
- **Payout**: COD → owner keeps cash, **owes platform commission**; Online (P2) → platform collects, pays owner minus commission.
- **Market**: Cairo + Alexandria at launch. B2C + B2B. iOS + Android. **Arabic-first** + English, full RTL.

## Roles
Renter (mobile) · Owner (mobile owner mode) · Admin/Ops (web/large-screen). Driver deferred.

## Key business rules
- Only **ID-verified owners** can publish listings (draft allowed unverified).
- **New renters (no history)** pay a **non-refundable trust fee**; returning renters skip it.
- **B2B / high-value renters** must be **ID-verified** before booking.
- Owner sets rates, fuel policy, accessories, delivery zone/fee, operated-vs-dry-hire, availability.
- Commission on every booking; on COD it's an owner→platform receivable.
- No double-booking incl. delivery/return buffers.
- Safety acknowledgment per booking (no indoor use; CO/ventilation warning).
- Cancellation/no-show governed by rating + blocklist (no prepayment at launch).

## Workflows (Section 5 of spec)
Owner onboarding+KYC → listing CRUD (specs, rates, fuel policy, zones, availability) →
renter discover/select (sizing helper, live estimate) → quote & book (commission, new-customer
fee, B2B ID, safety ack, OTP) → owner accept/coordinate → **COD + commission accrual** →
delivery & **digital handover** (condition photos, signature, fuel + hour-meter) → active rental
(extend, fuel top-up, fault) → return/inspection/settlement (fuel diff, overage, damage) →
two-way reviews → disputes (evidence, admin hold/resolve).

## Commission ledger / owner balance (Section 8.3 — key design point)
Owner holds the cash on COD, so platform must actively collect commission:
- (a) Owner prepaid wallet/credit (most reliable; pause listings on low balance)
- (b) Periodic invoicing (bill weekly/monthly; suspend on non-payment) ← recommended start
- (c) Offset against online payouts (once Phase 2 exists)

## Phasing (Section 16)
- **0 Foundation**: auth+roles, Arabic/RTL shell, owner KYC, listing CRUD
- **1 MVP**: search→request→accept→COD handover→close→two-way reviews; basic admin + manual commission
- **2 Trust & money**: new-customer fee rail, commission wallet/settlement, disputes UI, B2B ID
- **3 Online payments**: Egyptian aggregator, auto commission split, ETA e-invoicing
- **4 Scale**: more governorates, IoT, optional driver app, analytics

## Open questions (Section 18 — owner decisions needed)
1. New-customer fee collection on COD: owner collects cash (offsets commission) vs a small online rail just for fees?
2. Commission enforcement: start with periodic invoicing (b) or prepaid wallet (a)?
3. Allow owners to require their own **refundable** cash deposit (beyond the trust fee)?
4. Listing approval: auto-publish after owner KYC, or admin reviews each listing?
5. Pricing: owners set any price, or platform min/max guardrails?
6. Liability/insurance: any cover, or fully owner↔renter?
