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

---

## Remaining Features (priority order)

### NEXT (this loop)
- [ ] Owner: earnings tab monthly breakdown (group by month, animated bars)
- [ ] Generator detail: availability calendar (blocked dates highlighted)
- [ ] My Rentals: "track" button on active rental opens delivery address map
- [ ] Admin: flag count badge on Reports tab icon

### SOON
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
**Last commit:** `feat: New badge on listings, delivery address field in rental request`
**iOS local constraint:** ios/ is gitignored. After fresh checkout: set IPHONEOS_DEPLOYMENT_TARGET=16.0 in Podfile + xcodeproj, run pod install
**Next action:** ask-owner sheet, rental live cost preview, swipe-to-cancel pending rentals

---

## How the Loop Works
Each loop:
1. Read GOAL.md → pick top unchecked items from NEXT
2. Implement → `flutter analyze` → fix errors
3. Commit → push
4. Move items from NEXT to Shipped ✅
5. Replenish NEXT from SOON
6. Update "Loop State" section
7. `ScheduleWakeup(600s)` to continue
