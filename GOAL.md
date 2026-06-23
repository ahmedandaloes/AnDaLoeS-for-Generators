# AnDaLoeS App — Development Goal

**Vision:** Production-ready Egyptian generator rental marketplace.

---

## Shipped Features ✅
- Home: search, governorate chips, KVA + price filters, fuel type filter, search autocomplete, active filter pills, sort, favorites (haptic), unread badge, pull-to-refresh, "Top Rated" badge, fuel type chip on cards, skeleton loading cards, map icon
- Generator detail: photo carousel, call/WhatsApp, mini availability calendar, ratings, similar generators horizontal scroll, haptic on Rent Now, favorite FAB
- Notifications: realtime, mark-all-read, unread badge, grouped by day, swipe-to-dismiss, individual mark-as-read, rich icon colors per type
- Profile: rental stats, dark mode (persisted), language toggle (persisted), avatar photo upload (FilePicker → Supabase avatars bucket)
- My Rentals: conflict warning, rating badge, view receipt, owner accept/reject note shown to customer, chat button, empty state illustration
- Rental Receipt: gradient header, copy-as-text
- Owner Dashboard: requests, history, rate customer, earnings + monthly chart, accept/reject with optional message dialog, chat button, summary stats chips (Pending/Active/Done)
- Add Generator + Edit Generator: fuel type dropdown (diesel/petrol/gas/natural_gas/solar)
- Admin panel: company approval, reports, platform stats
- Company profile: stat chips (generator count, completed rentals)
- DB migrations 0011–0017 (favorites, notifications, avatar, fuel_type, owner_note, messages, status-change trigger)
- CI: flutter.yml with Flutter 3.32.x, analyze+test, APK build job
- CLAUDE.md agentic guide
- /goal + /loop skills for self-sustaining development across context windows
- Onboarding splash: 3-page PageView, SharedPreferences flag, first-launch only
- Rental request: booked dates shown before date picker; review & confirm flow
- Payment: COD confirmation screen with digital payment placeholder ("Soon")
- Chat: owner ↔ customer real-time thread per rental request (Supabase stream), unread message badges
- Architecture: feature-based structure — providers/ and widgets/ per feature; all files under 800 lines
- Map view: OpenStreetMap (flutter_map, no API key) with 27 Egyptian governorate pins, tap-to-preview card, View Details CTA
- Rental Offer screen (OFFER-XXXXXXXX): formal document for accepted rentals, share as text
- Tax Invoice screen (INV-XXXXXXXX): formal invoice for completed rentals with line-items table, PAID badge, share
- My Rentals: 4-tab bar (All / Active / Pending / Done) with per-tab count badges
- Profile: total amount spent + month-over-month trend indicator (↑↓)
- Company onboarding: description field + live preview card (name, city, bio)
- Generator cards: company name shown below title (storefront icon)
- Generator detail: avg response time badge (Responds in ~X hr) based on accepted/rejected requests
- Notifications: layered bell illustration with green checkmark badge for empty state
- Generator detail: share button sends name + KVA + price + city
- Home: Recently Viewed horizontal scroll section (last 5, with photo strip + Clear button)
- My Rentals Done tab: green gradient spending summary banner (total EGP + count)
- Owner Earnings: month chip selector to filter by month or All time
- Availability calendar: green for available days, red for booked
- Conflict UX: booked range chips turn red/filled when selected dates overlap
- Home screen: "Popular in [City]" horizontal section (top city auto-detected)
- Profile: inline phone number edit/add via dialog
- Gallery: swipe-down-to-dismiss with scale/opacity feedback + thumbnail strip
- GeneratorCard: press-scale animation (97% on tap-down, elastic back)
- Detail screen fav button: elastic bounce via TweenAnimationBuilder + Curves.elasticOut
- Similar generators: fix route bug + add price to card
- My Rentals: swipe-right = offer/invoice, swipe-left = cancel (Dismissible)
- Admin: Generators tab with approve/reject/toggle, extracted to admin_generators_tab.dart
- Owner Dashboard: today's earnings gradient card + Pending/Accepted/Active chips
- Home screen: "New Arrivals" section (7-day window, age badge per card)
- Profile: sign-out confirmation dialog with joined date, rental count, total spent
- Architecture: AppRoutes constants (23 routes, replaces 57 hardcoded strings); admin screen split into 4 tab files; GeneratorRepository data layer
- Generator detail: report-a-problem bottom sheet with 5 pre-labelled issue types; hero image expanded to 300px with gradient overlay + photo count badge; zoom/fade stretch modes
- Owner Dashboard: response-time goal chip (avg vs 2hr target, green ✓ / red ⚠)
- Notifications: tap routes to correct screen per type (accepted→offer, completed→invoice, message→chat, rating→rate)
- Global: PressScale widget; micro-animations on Accept + Review & Confirm CTAs
- DB fix 0019: accept/reject crash — dropped duplicate broken status-notification trigger (was inserting into a nonexistent notifications.rental_request_id column, rolling back every status change)
- DB fix 0020: generator_status enum gained `pending`+`rejected` — admin Generators tab no longer crashes; admins can reject/take down listings
- DB 0021: no-double-booking — partial GiST exclusion constraint blocks overlapping accepted/active rentals per generator (verified live: overlap blocked, pending allowed); friendly "already booked" error in all owner accept paths; accept-all now per-row (skips conflicts, reports count)

---

## 🚀 TOP PRIORITY: Launch Readiness (owner directive 2026-06-23)
Get the app **ready to use** end-to-end before adding more features. The core
journey must work with no dead ends: sign up → browse → book → owner accept →
active → complete → rate. Readiness audit running; blockers land in the
"Launch blockers" list below as found. Rule for the loop: **fix readiness
blockers before any new feature.** Money model stays parked (owner decides).

### Launch blockers (readiness audit 2026-06-24)
CRITICAL — marketplace couldn't function end-to-end (DB-layer chain). FIXED:
- [x] C1: companies missing `description` → owner onboarding insert failed (DB 0024 added column)
- [x] C2: no admin UPDATE policy on companies → "Approve company" silently rejected by RLS → catalog permanently empty (DB 0024 added companies_update_admin + generators_update_admin)
- [x] C3: was a blocker only if no admin existed — verified an admin profile already exists (not a blocker)
- [x] C4: owner stuck on "Under review" — downstream of C1–C2, now resolved (approval works)
- [x] H4: customer-facing raw `Error: $e` → routed through friendlyDbError (booking, company onboarding, rating)

HIGH — real-user auth. DECISION (owner 2026-06-24): **verified email now, phone later.**
- [x] Launch auth: EmailAuthScreen (/email-auth) — explicit sign-in/sign-up, email
      confirmation messaging (Supabase enforces confirmation at sign-in if enabled),
      friendly auth errors, guest browse. "Continue with email" is now the primary
      button on the login screen.
- [x] H1: `/dev-login` gated behind kDebugMode (works in debug for testing, hidden in release).
- [ ] Verify Supabase project setting: "Confirm email" should be ON for production
      (so unconfirmed accounts can't sign in). Owner to confirm in Supabase dashboard.
- [ ] Phase 2: phone OTP once owner provisions an SMS provider (Twilio/Vonage) — UI built; keep it.
- [x] H3: guest→registered upgrade — premium CTA on profile for guests opens a
      sheet that links email+password to the same anonymous user (updateUser), so
      favorites/rentals/chats carry over. Email confirmation applies if enabled.

MEDIUM (polish):
- [x] Delivery address/time now structured columns (DB 0025) — captured on request,
      shown to customer at confirm + to owner on the request card (ops can fulfill).
- [ ] Digital payment is "coming soon" stub (COD works) — tied to monetization decision
- [ ] company_documents table unused; verify RLS airtight (hardcoded publishable key)
- [x] company onboarding now saves governorate (was only city); location join deduped

---

## FOCUS: Validated Business Thesis (market research 2026-06-23)
Full strategy in `docs/BUSINESS_STRATEGY.md` + money model in `docs/MONETIZATION.md`.

**Thesis:** A trust-based booking marketplace for **B2B/SMB generator rental**
(events, construction, factories, telecom, agriculture) — NOT consumer
outage-backup (Egypt ended load-shedding in 2024–25; that demand is fading).
**Win on the whitespace no incumbent fills:** published day-rates + one-tap
verified booking + a trust layer. Money model: shift the flat 50 EGP fee → a
**percentage commission via digital escrow**, phased 8–10% → 12–15% as trust
features ship. Seed supply in **Cairo + Alexandria** first.

### Target rental workflow (money path)
browse → instant booking (calendar) → security DEPOSIT held → owner ACCEPTS →
escrow collects rent+deposit → ACTIVE → COMPLETED → commission auto-deducted,
owner paid out ≤3 working days → deposit released/claimed → both RATE.
(Commission & payments stay server-side via DB triggers, never the client.)

### NEXT (this loop) — buildable in-app now, no external dependency
- [x] **Money model: percentage commission.** commission_config switched fixed
      50 EGP → 10% (DB 0022, verified live); owner request card now shows
      projected net payout ("You receive EGP X · 10% platform fee") via
      commissionConfigProvider + projectCommission helper. Customer still sees
      the full total (commission is owner-charged).
- [ ] **Security deposit field** on generators + shown in booking + stored on
      rental_requests (foundation for the trust layer). → data-architect first
- [x] **Use-case/segment tags** on generators (DB 0023 use_cases text[] + GIN
      index). Owner picks them in add/edit (chips), customer filters by them in
      the browse filter sheet, shown on the detail screen. Shared
      kGeneratorUseCases constant. Operationalizes the B2B repositioning.
- [x] Revenue: admin Revenue tab — editable commission rate, accrued-vs-settled totals, per-commission "Mark collected" (ledger model; DB 0026 admin RLS). Cash-market revenue tracking now; online auto-collect (Fawry) later.
- [ ] Status state machine: guard invalid transitions at DB level (e.g. no rejected→active)
- [x] Double-booking: enforce no overlapping accepted/active rentals per generator (DB 0021)

### ⏳ DECISION PENDING — revenue collection model (owner to choose later)
A % commission isn't collectable on cash-on-delivery (money never flows through
the platform). Four options recorded in `docs/MONETIZATION.md §1b`:
(A) owner subscription + featured, (B) Fawry/escrow % commission, (C) owner
commission ledger / post-paid, (D) hybrid (subscription now, % later). Until
chosen: the 10% rate (DB 0022) and the owner request-card "platform fee" label
are **provisional** — accrued `commissions` rows are the accounting backbone but
nothing actually collects cash commission yet. Re-word the owner label once decided.

### SOON — needs external integration / compliance / decision
- [ ] **Digital escrow payments** (Paymob or Kashier): collect rent to platform
      account, auto-deduct commission, mass-payout owner ≤3 days. → release-ci + security-architect
- [ ] **Fawry pay-against-code** for the COD segment (capture "cash" into the platform)
- [ ] **Damage protection / basic insurance** (justifies raising take rate to 12–15%)
- [ ] **Anti-leakage**: off-platform-dealing detection (cancellation/contact-share patterns) + penalties
- [ ] **CBE payment-facilitator compliance review** (escrow account, EGP settlement, June-2025 PSP rules) before holding rent at scale
- [ ] Generator approval gate: new generators default to `pending` (PRODUCT DECISION — needs active moderation; enum already supports it)
- [ ] Referral credits (growth lever; coordinate with monetization-expert) + deep linking to listings (WhatsApp-native sharing)

### UI/UX POLISH (ongoing — clean, Uber-grade)
- [ ] Price transparency on cards/detail (day-rate always visible — our differentiator)
- [ ] Rental request: date range conflict chip UX improvements
- [ ] Accessibility audit (semantic labels, contrast ratios)

### DONE-WHEN
- [ ] 80%+ test coverage (current: placeholder only)
- [ ] Web support (currently passkeys SDK error)
- [ ] macOS desktop support
- [ ] Accessibility audit (semantic labels, contrast ratios)

---

## 🏆 Market-Readiness Roadmap (business experts 2026-06-24)
Story + market-challenge analysis in `docs/PRODUCT_STORY.md`. Synthesized from
product-strategy + marketplace-growth + monetization experts. Theme tags; effort
in (). Build NOW items in-app; SOON/LATER need integrations/decisions/advice.

### Fulfillment & Trust (on-time + confidence — the core promise)
- [ ] [NOW] Owner SLA acceptance clock — auto-expire requests ignored past a window (e.g. 4h)
- [ ] [NOW] Delivery confirmation — owner "out for delivery" → customer "received" (opt. photo) → ACTIVE, timestamped
- [ ] [NOW] Security deposit field (generator → rental_request; record-only now, hold later) — foundation of the trust layer
- [ ] [NOW] Verified-owner badge from company-approval state on cards/detail (wire the unused company_documents)
- [ ] [SOON] Fulfillment status timeline on the ticket (accepted→preparing→en route→delivered→active→returned)
- [ ] [SOON] Owner reliability score (on-time %, acceptance, cancellation) shown on listings
- [ ] [SOON] Two-sided dispute/claim flow (extend reports: damage/no-show/wrong-spec + evidence + admin adjudication)
- [ ] [SOON] Cancellation policy + penalties (windows, strikes, auto-suspend repeat offenders)
- [ ] [LATER] Backup-fulfillment fallback — suggest nearest equivalent when an accepted owner cancels late

### Growth (supply, demand, liquidity)
- [ ] [NOW] Public web listing pages (no-auth, SEO/Arabic URLs) per generator/company — organic discovery
- [ ] [NOW] WhatsApp deep-link sharing with rich preview (photo+kVA+rate+city), app/web fallback
- [ ] [NOW] Cairo+Alexandria supply-liquidity tracker (listings/city, %cities ≥N, request-without-match rate)
- [ ] [SOON] Owner quick-add / bulk listing flow (migrate OLX/Facebook owners with low friction)
- [ ] [SOON] Saved searches + "new match" alerts (reuse notifications + use_cases)
- [ ] [SOON] Two-sided referral invites with deep links (attribution; credit value = monetization)
- [ ] [SOON] First-booking nudge sequence (browse→request drop-off, segment-aware copy)
- [ ] [LATER] Seasonal summer-demand campaign hooks; repeat/re-book loop for telecom/agri; listing-quality score

### Monetization (revenue path forward)
- [ ] [NOW] Owner balance/statement view over the commission ledger (re-word provisional "platform fee")
- [ ] [NOW] Owner subscription + featured-listing fees — leakage-proof, collectable without a gateway (Med; needs a digital charge endpoint)
- [ ] [NOW] Unpaid-balance listing-suspension rule (anti-churn for the cash ledger)
- [ ] [SOON] Fawry pay-against-code — turn cash into platform-collected funds so % auto-deducts (High; owner = payout recipient)
- [ ] [SOON] Paymob/Kashier escrow — collect rent, auto-deduct, mass-payout ≤3 days (High; owner merchant acct)
- [ ] [SOON] Anti-leakage detection + penalty tiers; tiered/per-company rates (commission_config already supports override)
- [ ] [LATER] Damage protection/insurance add-on (justifies 12–15% take); CBE payment-facilitator compliance review (gates escrow)

### Tax & Compliance (Egypt — like Uber; get professional advice first)
- [ ] [NOW] VAT (14%) line + company tax-registration number on the Tax Invoice screen
- [ ] [NOW] Sequential immutable invoice/receipt numbers
- [ ] [NOW] Accounting export from Revenue tab (date-range CSV: commissions, payments, VAT collected)
- [ ] [SOON] Owner payout statements (for owner income reporting; WHT if required)
- [ ] [LATER] ETA e-invoicing integration (needs tax registration + ETA onboarding); confirm corporate tax/WHT with an Egyptian accountant

---

## Loop State (updated each iteration)
**Last iteration:** 2026-06-23
**Working branch:** `development` (main is integration/release)
**Mode:** continuous loop (owner directive — no timer waits; finish item → start next).
**Last commit:** `fix: company onboarding governorate + dedupe location`
**iOS local constraint:** ios/ is gitignored. After fresh checkout: set IPHONEOS_DEPLOYMENT_TARGET=16.0 in Podfile + xcodeproj, run pod install
**Next action:** money-model shift — switch commission_config to ~10% percentage + show fee/payout breakdown at request time (rental-workflow + supabase-db). See docs/BUSINESS_STRATEGY.md + docs/MONETIZATION.md.
**Strategy:** repositioned to B2B/SMB trust marketplace per market research 2026-06-23 (docs/BUSINESS_STRATEGY.md).

---

## How the Loop Works
Pattern: **Continuous-PR loop + De-Sloppify + Verification gate** (see the
autonomous-loops skill). GOAL.md is the cross-iteration context bridge
(`SHARED_TASK_NOTES.md` role). Each loop:
1. Read GOAL.md → pick top unchecked item(s) from NEXT
2. (non-trivial) Delegate via the Agent tool — investigate/build in PARALLEL
   through the project agent team; reviewer ≠ author
3. Implement → **de-sloppify** (remove dead code, over-defensive checks, raw
   error leaks) → `flutter analyze --no-fatal-infos` (zero errors AND warnings)
4. Verify (qa-gatekeeper): tests/build + live-DB check for any migration
5. Commit (conventional) → push to `development`
6. Move items NEXT → Shipped ✅; replenish NEXT from SOON
7. Update "Loop State"
8. `ScheduleWakeup(600s)` to continue — UNLESS an exit condition is met

### Exit conditions (don't loop forever — anti-pattern #1)
- **Completion:** NEXT is empty AND nothing remains to replenish from SOON →
  stop scheduling, report done.
- **Blocked:** a step needs a human decision (product call, secret, external
  access) → stop and ask rather than spin.
- **Safety bound:** if the same item fails its gate 3 iterations running →
  stop, capture the failure context in Loop State, ask for input.

### Quality gates (a change is NOT done until all pass)
- `flutter analyze --no-fatal-infos`: zero errors, zero warnings.
- Any DB change: numbered migration, applied + verified against the live DB
  (constraint/enum/trigger inspected; no new errors in logs).
- Money/notification logic stays server-side (DB triggers), never client.
- Feature-first structure honored (feature-structure-guardian).

### CI gate (risky changes)
For schema/auth/money changes, prefer a PR into `main` and wait for the
`flutter.yml` checks before merge, instead of pushing straight through.
