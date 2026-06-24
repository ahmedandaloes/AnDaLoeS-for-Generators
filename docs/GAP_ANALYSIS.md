# AnDaLoeS — Gap Analysis: build vs Requirements v2.0

Mapped against [REQUIREMENTS_v2.md](./REQUIREMENTS_v2.md). Legend: ✅ built · 🟡 partial · ❌ missing.

## ✅ Already built (much of Phase 0–1 + parts of 2)
- Marketplace model; owners list/maintain generators; admin approval.
- Booking lifecycle: request → owner accept/decline → active → completed; two-way ratings (+ integrity rules).
- **Owner delivers** + **delivery handshake** ("Out for delivery" → "Confirm delivered · start") with `delivered_at`.
- **% commission per booking**, accrued as **owner→platform receivable** (commission ledger; owner "fees owed"; admin Revenue tab with mark-collected). ≈ enforcement model (b) manual.
- **COD** flow with itemized payment summary (rental + refundable deposit + total payable).
- **No double-booking** (GiST exclusion constraint) + availability calendar + conflict UX.
- Search + filters (governorate/kVA/price/fuel/use-case/sort, **persisted**); map view.
- **VAT-itemized invoices** with sequential invoice numbers + **configurable tax** (tax_config) + commission/VAT export.
- Admin console (web-capable): companies, generators, reports, **Ops**, **Revenue**, stats, users.
- Reliability/trust signals (acceptance · on-time · response), verified badges.
- In-app realtime notifications; chat owner↔renter; reports (basic dispute intake).
- Refundable **deposit** per listing (owner-set) — see Q3.
- Repository/REST architecture; app-wide friendly errors; tokenized status colors; 18 unit tests.

## 🟡 Partial — needs completion
- **Owner KYC / ID-verified before listing**: admin approves *companies*, but national-ID/business-doc upload + verification gating is not wired (the `company_documents` table is unused). Spec rule: only ID-verified owners publish.
- **Commission enforcement**: ledger + manual mark-collected exists (≈ model b, manual). No automated weekly/monthly invoicing or listing suspension on non-payment, no prepaid wallet (a).
- **Disputes**: report intake exists; no evidence (photos/meter) capture, no payout/charge hold, no admin resolve workflow.
- **Delivery zones & fee**: city/governorate + per-request delivery address/time exist; no per-listing delivery zone polygons or distance-based delivery fee (Maps-based).
- **Reporting/analytics**: admin stats + revenue exist; not full GMV / commission collected-vs-outstanding / utilization dashboards.
- **Phone OTP**: UI built; needs an SMS provider provisioned (flagged).

## ❌ Missing — net-new work
- **Arabic-first + full RTL** (NON-FUNCTIONAL, high priority): localization scaffold exists but the app is English-first; needs Arabic translations as default + RTL verification across screens.
- **New-customer non-refundable trust fee** (new renters only, history-based) — distinct from the refundable deposit. Includes the COD collection question (Q1).
- **B2B / high-value renter ID verification** before booking.
- **Digital handover**: condition photos, renter signature, starting fuel level + hour-meter at delivery; **return inspection** (ending fuel/meter, damage, overage) + cash settlement. Offline-tolerant.
- **Sizing helper** (guided power-need → recommended kVA).
- **Active-rental actions**: extend rental, fuel top-up request, fault report (mid-rental).
- **Listing fields**: operated-vs-dry-hire, fuel policy, accessories/add-ons, phase/noise/runtime/outlets, per-listing availability editor.
- **Safety acknowledgment per booking** (no indoor use; CO/ventilation) gating confirmation.
- **Blocklist** for no-shows/abuse.
- **Offline tolerance** for owner handover (queue + sync).

## Phase 2/3/4 (correctly deferred — external setup)
- Online payments via Egyptian aggregator (Paymob/Kashier/Geidea/PayTabs); auto commission split.
- ETA e-invoicing (B2B); FCM push; IoT; outsourced driver app.

## Decisions that gate the next build (Section 18)
Q1 new-customer fee collection · Q2 commission enforcement (a vs b) · Q3 owner refundable deposit (already built — keep?) · Q4 listing approval (auto-after-KYC vs admin-per-listing; currently admin-per-generator) · Q5 pricing guardrails · Q6 liability/insurance.

## Recommended next sequence (after decisions)
1. **Owner KYC doc upload + publish gating** (closes a core Phase-0 rule; `company_documents` already exists).
2. **Arabic-first + RTL** groundwork (non-functional, pervasive — do early before more screens).
3. **Digital handover v1** (condition photos + fuel/meter readings on delivery & return) — the biggest fulfillment/trust gap and the evidence base for disputes.
4. **New-customer trust fee** (per Q1) + **safety acknowledgment** at checkout.
5. **Listing fields** (operated/dry-hire, fuel policy, accessories) + **B2B renter ID**.
6. Disputes workflow, delivery-zone fees, analytics, then Phase 3 payments.
