# Product Requirements (from founder interview)

This is the single source of truth for **business rules**. Technical choices
live in `ARCHITECTURE.md`; schema in `DATA_MODEL.md`; build order in
`ROADMAP.md`.

> Status: decided in founder interview, 2026-06-22. Open item: **app name**.

---

## 1. What it is
A nationwide (Egypt) marketplace to rent electrical **generators**. Companies
list generators; customers rent them; the platform earns a commission on
completed rentals. Open for any company to join, subject to platform approval.

## 2. Decisions

| Topic | Decision | Notes |
|---|---|---|
| **Commission** | **Fixed amount per rental**, configurable | Start with a fixed fee (as your dad does); make it adjustable per platform cost/plans. Design keeps room for a percentage later. |
| **Delivery & operation** | **Owner handles everything** | Owner/company delivers, sets up, fuels, and operates the generator. The app connects and tracks; it does **not** manage logistics. |
| **Payment** | **Cash on delivery (for now)** | No online payment at launch. Customer pays the owner in cash; the rental is recorded in-app. Paymob/Fawry come in a later phase. |
| **Pricing** | **Day / week / month rates** | Owner sets all three. Longer = cheaper. |
| **Definition of a "day"** | **1 rental day = 8 operating hours** | A "day" is an 8-hour working day, not 24h. This is core to price calculation. |
| **Languages** | **Arabic + English** | Both at launch, with a language switch. Arabic is RTL. |
| **Coverage** | **All of Egypt** | Nationwide listings; customers filter by governorate / city. |
| **Customer signup** | **Open — phone OTP only** | Anyone with a verified phone can rent immediately. No customer document check. |
| **Company signup** | **Open, but verified & approved by platform** | Any company can apply; generators stay hidden until an admin approves (see `DATA_MODEL.md`). |
| **App name** | **TBD** | Founder asked for naming help — options proposed separately. |

## 3. What this means for scope

- **Online payments are deferred**, by choice — this is the one piece pulled
  out of v1. Everything else (auth, listings, search, rental loop, owner
  platform, company verification, commissions, ratings, admin panel) is in v1.
- Because the owner does delivery & operation, the app needs **no driver/
  logistics module** — a big simplification.
- Price math must use an **8-hour day** and pick the best of day/week/month
  rates for the chosen duration.

## 4. Open questions to revisit later
- Exact fixed commission amount (and when to switch to a %).
- Required verification documents for companies.
- Deposit / damage handling (currently none — cash, owner-operated).
- Cancellation rules and any fees.
