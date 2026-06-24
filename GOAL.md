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

## 🗓️ NEXT 10 SPRINTS (roadmap, 2026-06-24)
Operative forward plan after the Arabic-first rollout. Each sprint = a coherent
theme the loop works one verified item at a time (analyze 0 / tests green /
conventional commit / push / tick here). Priority order: launch-readiness &
trust → conversion → growth → monetization/compliance. **🔒 = blocked on an
owner/external decision** (loop skips until unblocked); everything else is
buildable in-app now. Definition of done (DoD) per sprint listed.

### Sprint 1 — Trust signals (verification + reliability surfacing) ✅
- [x] Verified-owner badge on generator cards + detail (from `companies.verification_status`; wire the approval state through the generator query/repository)
- [x] Detail: hoist ONE compact "verified + on-time % + acceptance" trust row above the fold; unify the 3 inconsistent badge styles
- [x] Owner request card: "collect EGP X deposit on delivery" reminder
- [x] Adopt shared `qualityColor`/status tokens on remaining screens — `generatorStatusColor()` added; inline switch dupes removed from owner_dashboard_screen + admin_generators_tab
- DoD: trust state visible end-to-end; new strings localized en+ar; no duplicate color maps. ✅

### Sprint 2 — Booking integrity & lifecycle correctness ✅
- [x] DB status state-machine guard — block invalid transitions (rejected→active, completed→pending, …) via `mcp apply_migration`
- [x] Standardize priced-days (inclusive end date) off-by-one — +1 fix in rental_request_screen
- [x] "Mark as received" button removed; RLS restricts customers to cancel only
- DoD: invalid transitions impossible at DB level; day math consistent; no RLS-rejected client writes.

### Sprint 3 — Conversion: frictionless request ✅
- [x] Detail: guests can now navigate to date-picker; auth required only at "Send request" (PaymentConfirmationScreen._confirm)
- [x] Detail: sticky Rent Now FAB always visible (no scroll-hide); share/copy/report moved to AppBar actions
- DoD: browse→request drop-off reduced; auth check at final submit step.

### Sprint 4 — Accessibility & UX polish ✅
- [x] ≥48dp tap-target pass — filter pills container 38→48, all my_rentals buttons 36/38/40→48
- [x] My Rentals: completed state buttons (Invoice/Receipt/Report) collapsed into 3-column row
- [x] Accessibility audit: tooltip on all icon-only buttons (profile, back, password toggle, close, clear search, map close, gallery close); showPassword/hidePassword en+ar
- [x] Document screens (invoice/receipt/offer): dark-mode theming — hardcoded white/grey/black replaced with colorScheme tokens in rental_offer_screen, invoice_screen, rental_receipt_screen (committed)
- DoD: a11y scan clean; no <48dp targets; documents readable in dark mode.

### Sprint 5 — Growth: shareable & discoverable (partial)
- [x] Share URL fixed (/generator → /generators) + bilingual CTA + first photo URL
- [ ] Deep linking to listings (GoRouter deep links + Android App Links config)
- [ ] Saved searches + "new match" alerts (reuse notifications + use_cases)
- DoD: a shared link opens the right listing; saved search fires a notification on match.

### Sprint 6 — Public web listing pages (SEO/organic) 🔒(web support fix)
- [ ] Fix web build (passkeys SDK error) enough to serve read-only pages
- [ ] No-auth public generator/company pages, Arabic-first URLs, SEO/OpenGraph meta
- DoD: a generator is viewable + indexable without the app. (Blocked portion: web SDK fix.)

### Sprint 7 — Fulfillment timeline & disputes
- [x] Fulfillment status timeline on the ticket (DB 0036 rental_timeline_events + auto-trigger; _StatusTimeline in My Rentals + _OwnerTimeline in OwnerRequestCard)
- [x] Digital handover: DB 0037 rental_handovers (fuel_level, meter_reading, note, UNIQUE delivery+return per rental); owner dialogs on "Confirm Delivered" + "Mark Completed"; customer sees handover summary on active/completed card
- [ ] Two-sided dispute/claim flow (extend reports: damage/no-show/wrong-spec + evidence + admin adjudication)
- DoD: every active rental has an auditable timeline; disputes have an admin adjudication path.

### Sprint 8 — Owner tooling & supply growth
- [ ] Owner quick-add / bulk listing flow (low-friction OLX/Facebook migration)
- [x] Add Generator: clone listing — copy_all_outlined button in owner generator tile passes full data (all 17 fields) as GoRouter extra → AddGeneratorScreen prefill
- [ ] Listing fields: operated vs dry-hire, fuel policy, accessories (v2 spec)
- [ ] Supply-thin owner nudges (tie to the governorate tracker)
- DoD: an owner can list 5 generators in minutes; new spec fields captured + filterable.

### Sprint 9 — Monetization (collectable without a gateway) 🔒(owner: revenue model)
- 🔒 [ ] Revenue-collection model decision (A subscription / B Fawry-escrow / C ledger / D hybrid) — owner picks (docs/MONETIZATION.md §1b)
- [ ] Owner subscription + featured-listing fees (needs a digital charge endpoint)
- [ ] Unpaid-balance listing-suspension rule (anti-churn for the cash ledger)
- [ ] Owner payout statements (income reporting; WHT if required)
- DoD: a collectable revenue mechanism live once the model is chosen; ledger drives suspensions.

### Sprint 10 — Notifications, payments & compliance 🔒(external)
- 🔒 [ ] FCM push + flutter_local_notifications (needs android/ios native config + FCM project)
- 🔒 [ ] Phone OTP (needs SMS provider — Twilio/Vonage)
- 🔒 [ ] Digital escrow (Paymob/Kashier) / Fawry pay-against-code (needs merchant acct + CBE review)
- 🔒 [ ] Tax: confirm VAT treatment + customer % with accountant; ETA e-invoicing onboarding
- [ ] Auto-expire stale pending requests (edge fn/cron) — buildable once an edge fn is allowed
- DoD: real-time push + collected payments + compliant invoicing (gated on the owner/external items).

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
- [x] **Security deposit field** — owner sets a refundable deposit; shown at booking; stored on rental_requests (DB 0027)
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
- [~] Test coverage: real unit tests for core business logic (commission, db_error, ICS, sizes, use-cases) — 11 tests passing. More to follow toward 80%.
- [ ] Web support (currently passkeys SDK error)
- [ ] macOS desktop support
- [ ] Accessibility audit (semantic labels, contrast ratios)

---

## 🏆 Market-Readiness Roadmap (business experts 2026-06-24)
Story + market-challenge analysis in `docs/PRODUCT_STORY.md`. Synthesized from
product-strategy + marketplace-growth + monetization experts. Theme tags; effort
in (). Build NOW items in-app; SOON/LATER need integrations/decisions/advice.

### Fulfillment & Trust (on-time + confidence — the core promise)
- [~] [NOW] Owner SLA: pending requests show "requested Xh ago" urgency chip (green<1h→amber<4h→red) nudging fast accept. Auto-expire (needs cron/edge fn) → SOON.
- [ ] [NOW] Delivery confirmation — owner "out for delivery" → customer "received" (opt. photo) → ACTIVE, timestamped
- [x] [NOW] Security deposit field (generator + rental_request, DB 0027) — owner sets it, shown to customer at booking, stored on the request
- [ ] [NOW] Verified-owner badge from company-approval state on cards/detail (wire the unused company_documents)
- [ ] [SOON] Fulfillment status timeline on the ticket (accepted→preparing→en route→delivered→active→returned)
- [x] [NOW] Owner reliability — shared companyReliabilityProvider (acceptance, response, on-time, completed). On-time % badge added to generator detail; company profile migrated to the shared provider (removed duplicate).
- [ ] [SOON] Two-sided dispute/claim flow (extend reports: damage/no-show/wrong-spec + evidence + admin adjudication)
- [~] [NOW] Cancellation policy shown at booking ("free while pending; coordinate with owner after accept"). Penalties/strikes → SOON.
- [ ] [LATER] Backup-fulfillment fallback — suggest nearest equivalent when an accepted owner cancels late

### Growth (supply, demand, liquidity)
- [ ] [NOW] Public web listing pages (no-auth, SEO/Arabic URLs) per generator/company — organic discovery
- [ ] [NOW] WhatsApp deep-link sharing with rich preview (photo+kVA+rate+city), app/web fallback
- [x] [NOW] Supply-by-governorate tracker in Admin Stats (available generators per area, "thin" flag <3) — via GeneratorRepository.countAvailableByGovernorate (repository, no inline dup)
- [ ] [SOON] Owner quick-add / bulk listing flow (migrate OLX/Facebook owners with low friction)
- [ ] [SOON] Saved searches + "new match" alerts (reuse notifications + use_cases)
- [ ] [SOON] Two-sided referral invites with deep links (attribution; credit value = monetization)
- [ ] [SOON] First-booking nudge sequence (browse→request drop-off, segment-aware copy)
- [ ] [LATER] Seasonal summer-demand campaign hooks; repeat/re-book loop for telecom/agri; listing-quality score

### Monetization (revenue path forward)
- [x] [NOW] Owner balance: Owner Earnings shows "Platform fees owed (all time)" — cumulative unsettled commission to settle (accrued vs settled from commissions). Makes the cash ledger real for owners.
- [ ] [NOW] Owner subscription + featured-listing fees — leakage-proof, collectable without a gateway (Med; needs a digital charge endpoint)
- [ ] [NOW] Unpaid-balance listing-suspension rule (anti-churn for the cash ledger)
- [ ] [SOON] Fawry pay-against-code — turn cash into platform-collected funds so % auto-deducts (High; owner = payout recipient)
- [ ] [SOON] Paymob/Kashier escrow — collect rent, auto-deduct, mass-payout ≤3 days (High; owner merchant acct)
- [ ] [SOON] Anti-leakage detection + penalty tiers; tiered/per-company rates (commission_config already supports override)
- [ ] [LATER] Damage protection/insurance add-on (justifies 12–15% take); CBE payment-facilitator compliance review (gates escrow)

### Tax & Compliance (Egypt — like Uber; get professional advice first)
- [x] [NOW] Tax Invoice: VAT (14%) breakdown (subtotal excl. VAT + VAT line, treating totals as VAT-inclusive) + company tax-reg# / CR in footer (core/config/company_info.dart — set real values before production)
- [x] [NOW] Sequential immutable invoice numbers (DB 0028: invoice_seq + invoice_no stamped on completion via BEFORE trigger; invoice shows INV-001001…)
- [ ] [NOW] Accounting export from Revenue tab (date-range CSV: commissions, payments, VAT collected)
- [ ] [SOON] Owner payout statements (for owner income reporting; WHT if required)
- [x] [NOW] Commission + VAT accounting export from Revenue tab (CSV)
- [x] [NOW] Configurable customer tax (tax_config: rate/label/when; admin-editable) — owner sets dad's real % (e.g. 2% on invoice). Confirm with accountant.
- [ ] [SOON] Owner payout statements (for owner income reporting; WHT if required)
- [ ] [LATER] ETA e-invoicing integration (needs tax registration + ETA onboarding); confirm corporate tax/WHT with an Egyptian accountant

### Owner directives (2026-06-24) — to schedule
- [x] [NOW] Role separation audit (RLS): rental_requests (customer cancel-only, owner via owns_company, admin), generators (owner/admin only), messages (rental parties only) — all solid. FIXED gap: ratings could be inserted by anyone → now restricted to a party of a COMPLETED rental + unique per rater/rental (DB 0030).
- [~] [SOON→started] Admin Ops dashboard (7th tab): overdue active rentals, stale pending (>24h), accepted-not-started — via new RentalRepository (repository layer). More ops views to follow.
- [x] [NOW] Calendar access — "Add to calendar" on My Rentals exports an .ics (any calendar app, no native permission/package). Reminders via calendar app.
- [ ] [SOON] Notification access — device push notifications (FCM + flutter_local_notifications) with permission request; currently only in-app realtime. Needs native config (android/ios gitignored) + FCM setup.

---

## 🎨 Page Improvement Plan (product-owner + UX experts, 2026-06-24)
Per-page review of the live code. Implement NOW items in the auto-loop on `development`.

### Cross-cutting [NOW] — highest leverage (clear many items at once)
- [x] Shared AppErrorState rolled out app-wide — all ~19 screens (detail, my_rentals, notifications, owner dashboard + tabs, earnings, edit-generator, chat, offer/receipt/invoice, all admin tabs, map, company profile) now show a friendly error + retry instead of raw $e.
- [~] Status colors tokenized — shared core/theme/status_colors.dart (rentalStatusColor + qualityColor) replaces duplicated mappings in My Rentals + owner request card. More screens to adopt qualityColor/cs tokens next.
- [ ] ≥48dp tap-target pass — home sort/favorites/login pills, detail small FABs, owner request-card buttons, dashboard Earnings button (32px), _MonthChip, my_rentals report/receipt/calendar controls.
- [x] Chat: auto-scroll only on new messages (guarded by message-count change) — no longer fires every rebuild or fights user scroll-up.

### Business wins [NOW] (product owner)
- [ ] Detail: guest can pick dates/address first; require auth only at "Send request" (recovers the biggest browse→request drop-off).
- [x] Delivery handshake (DB 0031 delivered_at): owner "Out for delivery" → "Confirm delivered · start rental" (accepted→active); customer sees an "Out for delivery — on its way" banner. Owner-driven (no customer→active RLS hole). Feeds on-time data via delivered_at.
- [x] Payment: itemized summary — Rental (N days, best-rate noted) + Refundable deposit + Total payable on delivery, as a clean breakdown card. (Sticky bottom bar = SOON.)
- [ ] Detail: hoist a compact verified + on-time/acceptance trust row above the fold (unify the 3 inconsistent badge styles).
- [x] My Rentals: reads structured delivery_address (regex note-parsing removed); deposit status line (collected on delivery → held → returned). Track Delivery button →48dp. Guest-bookable detail deferred (auth-resume flow is fragile — needs review).
- [ ] Owner request card: echo deposit "collect EGP X on delivery" reminder; owner dashboard acceptance/on-time chips.
- [x] Home filters/sort persisted via shared_preferences (restored at launch, saved on change; search text stays transient). +2 round-trip tests.

### [SOON]
- [ ] Detail: move share/copy/report into AppBar so Rent Now dominates. Add cancellation/terms acknowledgement at payment.
- [ ] My Rentals: reduce 7 stacked buttons to one primary + overflow; show cancellation reason on cancelled cards.
- [ ] Company profile: show review text + documents-verified indicator. Add Generator: clone listing + local draft.
- [ ] Login: friendly auth errors + resend-code. Notifications: list skeleton + stronger unread signal.
- [ ] Document screens (invoice/receipt/offer): theme the scaffold/greens (dark-mode), friendly errors, format ISO dates.
- [ ] Home: min-kVA filter + fuel/verified on card; saved-search alerts (favorites + use_cases + notifications).

---

## Loop State (updated each iteration)
**Last iteration:** 2026-06-24 — Arabic-first rollout COMPLETE (default `ar`+RTL, both QA agents addressed). Now executing the **Next 10 Sprints** roadmap (see section above).
**Working branch:** `development` (main is integration/release)
**Mode:** continuous loop (owner directive — no timer waits; finish item → start next).
**Last commit:** `fix: Sprint 4 dark-mode — invoice screen colorScheme tokens`
**iOS local constraint:** ios/ is gitignored. After fresh checkout: set IPHONEOS_DEPLOYMENT_TARGET=16.0 in Podfile + xcodeproj, run pod install
**Next action:** Sprint 7 — Digital handover: delivery + return photos captured by owner, fuel/meter readings, stored in rental_timeline_events or new handover table.
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

---

## 📘 Requirements v2.0 alignment (owner spec, 2026-06-24)
The owner's authoritative spec is captured in [docs/REQUIREMENTS_v2.md](docs/REQUIREMENTS_v2.md);
build-vs-spec gap analysis in [docs/GAP_ANALYSIS.md](docs/GAP_ANALYSIS.md).
Much of Phase 0–1 is built (marketplace, booking lifecycle, owner delivery + handshake,
% commission ledger/COD, no-double-booking, VAT invoices, admin console, search).
Key remaining: owner KYC publish-gating, Arabic-first/RTL, digital handover (photos+fuel/meter),
new-customer trust fee, B2B renter ID, listing fields (operated/dry-hire, fuel policy, accessories),
disputes workflow. Decisions needed: Section 18 (commission enforcement, trust-fee collection,
listing approval, pricing guardrails, liability). Sequence proposed in GAP_ANALYSIS.md.

## 🌍 Arabic-first + RTL rollout (owner decision 2026-06-24)
Decision: Arabic default + full RTL. State: RTL infra present (gen-l10n Global delegates, `ar` supported, toggle); only ~14 strings externalized, ~345 hardcoded English Text() across ~28 screens.
Plan (loop, screen-by-screen): (1) grow app_en.arb + app_ar.arb (real Arabic) with each screen's strings; (2) replace hardcoded Text() with AppLocalizations; (3) RTL audit — EdgeInsets.only(left/right) → start/end, Align/Row directionality; (4) flip locale default to Arabic once the bulk is translated (avoid half-Arabic UI). Shared/common strings first (highest leverage), then high-traffic screens (home, detail, rental request, my rentals, owner dashboard), then the rest.
- [x] Foundation: common strings (actions/errors) in en+ar; AppErrorState localized (app-wide).
- [~] Localized: Profile + Home + Generator Detail (call/share/copy/save/report/Rent Now, acceptance+on-time stats via placeholders, price estimate) with real Arabic; RTL paddings→Directional. Next: owner request_card + earnings → admin tabs → rest. (Owner dashboard main strings done; a few secondary dialog/verification bodies pending.) Search hint + sort labels + section titles + documents pending. Search hint + sort labels + section titles pending. Search hint + sort labels + section titles pending.
- [ ] RTL padding/Align audit per screen as localized.
- [ ] Flip default locale to Arabic when ≥ ~80% strings translated.

## 🧪 Arabic/RTL QA findings (arabic-qa-expert, 2026-06-24) — action list
Key parity PASS (310 keys, all translated; en/ar count diff is just @-metadata). Translation quality strong + glossary-consistent. To fix:
- [ ] HIGH: fully-English screens (invisible in Arabic) — rental_offer, invoice, rental_receipt, add_generator, edit_generator.
- [ ] MEDIUM: partially-localized screens using LITERALS where ARB keys already exist — profile leftover dialogs (signOutQuestion/displayName/createAccount…), email_login_screen, rate_rental, generator_filter, map_screen, report_screen, search_autocomplete, admin leftovers, chat date labels (Today/Yesterday hardcoded at chat_screen ~336/339 despite today/yesterday keys).
- [ ] MEDIUM: ICU plurals only have =1/other — add Arabic dual(=2)/few/many for rentalDaysLine + completedRentalsCount; verify 1/2/3/11/100.
- [ ] MEDIUM: wrap LTR runs (EGP amounts, INV-/offer numbers, phone, dates) in Directionality.ltr to avoid RTL scrambling; or use ج.م suffix + Arabic digits.
- [ ] RTL hazards remain in 9 files (EdgeInsets.only(left/right), Alignment.centerLeft/Right) — switch to EdgeInsetsDirectional / AlignmentDirectional (verify chat bubbles which mirror by isMe intentionally).
- [ ] LOW: wording — stay "البقاء"→"ابقَ", skip "تخطٍّ"→"تخطّي"; localize 'Error: $e' snackbars; AR @-metadata absent (OK).
- [ ] CRITICAL-per-spec (do in FINAL cycle): default locale not Arabic yet (locale_provider state null → device locale). Flip to const Locale('ar') once screens above are localized.

## 🔒 Functional QA findings (qa-expert, 2026-06-24) — security + bugs
FIXED this cycle:
- [x] CRITICAL: self-escalation to role='admin' via PostgREST — DB 0032 trigger lock_profile_role (only admin can change role).
- [x] CRITICAL: owner self-approving own company (verification_status) — DB 0032 trigger lock_company_verification (admin only).
- [x] CRITICAL/MED: customer could cancel accepted/active via API — DB 0032 tightened rental_requests_update_customer USING to status='pending'.
- [x] HIGH: HomeScreen price/capacity sort crashed on null fields — null-safe numeric sort.
TODO (next cycles):
- [x] HIGH: "Mark as received" removed — completion is owner-driven via delivery handshake; customer RLS now blocks status=completed writes.
- [x] HIGH: router role-gating — cached role provider (refreshed on auth change); GoRouter redirect sends non-admins away from /admin and non-owners/non-admins away from /owner/* (defense-in-depth on RLS). /owner-dashboard stays open (onboarding entry).
- [x] HIGH: guest/anonymous gating — detail Rent Now/report/favorite require a real (non-anonymous) account (push login); company onboarding shows "create an account first" for anonymous users.
- [x] VAT consistency: shared vatBreakdown helper used by invoice; payment confirmation now shows a VAT line (subtotal + label+%) when tax_config.applies_when=='always' (total payable unchanged — price_total is VAT-inclusive). NOTE: VAT treatment (inclusive vs added-on) + applies_when policy need owner/accountant confirmation.
- [x] MED: completion trigger now clamps commission to [0, price_total] (DB 0033) — owner net never negative.
- [ ] MED: priced days (exclusive) vs blocked days (inclusive daterange) off-by-one; standardize.
- [x] MED: rate + receipt screens now gate on completed status when reached by route (friendly state otherwise).

## 🌐 DEFAULT LANGUAGE: ARABIC (shipped)
The app now launches in **Arabic with full RTL** by default (Arabic-first).
- Every screen is localized with real, natural Arabic; DB values stay English.
- Arabic plurals use proper categories (zero/one/two/few/many/other).
- **To switch to English:** Profile → Language → English. The choice persists across launches and overrides the Arabic default.

## ✅ Post-rollout QA (both agents) — addressed
Functional/regression QA: 0 CRITICAL/HIGH (wiring, ICU args, l-scope/null-safety, DB-value separation all verified correct).
Arabic/RTL QA: Arabic quality high; fixed — directional arrow glyph removed (continueToDocuments), chat bubbles/typing indicator now AlignmentDirectional + BorderRadiusDirectional, ≤→حتى, forNDays/daysCount converted to proper Arabic plurals, طلبًا. Localized leftover English: invoice section labels (Services Rendered/Rental Details/Generator rental), offer Note-from-Owner, my-rentals Offer, profile Account, add/edit-generator labels (Fuel type/Best for/Governorate), owner status chips (request_card + dashboard), and the customer search hint. ~16 new ARB keys.
Remaining LOW (optional): owner sort chips, raw 'Error: $e' snackbars, dev/admin minor labels, EGP-vs-ج.م currency token consistency.

## 🏁 ARABIC-FIRST ROLLOUT — COMPLETE
- ~31 screens fully localized (en + real natural ar); default locale = Arabic + RTL; English switchable in Profile → Language (persists).
- DB values stay English/codes (fuel/status/reason/doc-type/governorate) — queries + RLS unaffected.
- Arabic plural grammar (zero/one/two/few/many/other) for day & rental counts.
- RTL-safe: directional insets/alignment/border-radius; chat bubbles mirror correctly.
- Both QA agents run; all CRITICAL/HIGH/MED findings fixed; owner sort chips localized.
- **Currency token decision:** raw numeric amounts keep Latin "EGP" (LTR-stable in document tables); Arabic "ج.م" used in Arabic UI labels (pricing/earnings/filters). Intentional — left as-is.
- Remaining LOW (optional, deferred): raw 'Error: $e' diagnostic snackbars, dev/admin-only minor labels.
- All work on `development`; every step analyze-clean (0 errors/warnings) + 22 tests green.
