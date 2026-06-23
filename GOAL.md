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

## FOCUS: Business Workflow (owner directive 2026-06-23)
The loop now prioritizes the rental transaction lifecycle & revenue model
over UI polish. Core workflow: browse → request → accept → pay → active →
complete → commission → rate. Harden each transition + the money path.

### NEXT (this loop)
- [ ] Pricing transparency: show fee/commission breakdown at request time
- [ ] Status state machine: guard invalid transitions at DB level (e.g. no rejected→active)
- [ ] Commission: admin can edit commission_config rate from the panel (currently DB-only)
- [x] Double-booking: enforce no overlapping accepted/active rentals per generator (DB 0021)

### SOON
- [ ] Generator approval gate: new generators default to `pending` and require admin approval before going public (PRODUCT DECISION — needs active moderation commitment; enum already supports it. Route to product-strategy-expert.)
- [ ] Push notifications: FCM integration with Supabase edge function
- [ ] Referral code system: users get discount for referring friends
- [ ] Deep linking: share generator page via URL
- [ ] Advanced search: save search, price history chart

### UI/UX POLISH (ongoing — improve with every loop)
- [ ] Rental request: date range conflict chip UX improvements
- [ ] Admin: better stats charts, CSV export
- [ ] Accessibility audit (semantic labels, contrast ratios)

### DONE-WHEN
- [ ] 80%+ test coverage (current: placeholder only)
- [ ] Web support (currently passkeys SDK error)
- [ ] macOS desktop support
- [ ] Accessibility audit (semantic labels, contrast ratios)

---

## Loop State (updated each iteration)
**Last iteration:** 2026-06-23
**Working branch:** `development` (main is integration/release)
**Last commit:** `feat: prevent double-booking (DB 0021 exclusion constraint) + friendly accept errors`
**iOS local constraint:** ios/ is gitignored. After fresh checkout: set IPHONEOS_DEPLOYMENT_TARGET=16.0 in Podfile + xcodeproj, run pod install
**Next action:** pricing/commission breakdown at request time; admin-editable commission rate. Delegate via Agent tool to parallelize (investigation + build).

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
