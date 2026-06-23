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

---

## Remaining Features (priority order)

### NEXT (this loop)
- [ ] Generator detail: average response time badge (based on owner acceptance speed)
- [ ] Generator card: show company name below title
- [ ] Owner Dashboard: pull-to-refresh on Requests and History tabs
- [ ] Notifications: empty state illustration when no notifications

### SOON
- [ ] Push notifications: FCM integration with Supabase edge function
- [ ] Referral code system: users get discount for referring friends
- [ ] Deep linking: share generator page via URL
- [ ] Advanced search: save search, price history chart

### UI/UX POLISH (ongoing — improve with every loop)
- [ ] Generator detail: better hero image aspect ratio, share button
- [ ] Rental request: smarter conflict UX with exact blocked date ranges
- [ ] Global: micro-animations on state transitions (card tap, button press feedback)
- [ ] Global: pull-to-refresh on Owner Dashboard list views
- [ ] Admin: better stats charts, export CSV

### DONE-WHEN
- [ ] 80%+ test coverage (current: placeholder only)
- [ ] Web support (currently passkeys SDK error)
- [ ] macOS desktop support
- [ ] Accessibility audit (semantic labels, contrast ratios)

---

## Loop State (updated each iteration)
**Last iteration:** 2026-06-23
**Last commit:** `feat: My Rentals tab bar, profile spending stats, company description preview`
**iOS local constraint:** ios/ is gitignored. After fresh checkout: set IPHONEOS_DEPLOYMENT_TARGET=16.0 in Podfile + xcodeproj, run pod install
**Next action:** avg response time badge + pull-to-refresh on Owner Dashboard + notifications empty state

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
