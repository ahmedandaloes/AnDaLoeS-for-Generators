# AnDaLoeS App — Development Goal

**Vision:** Production-ready Egyptian generator rental marketplace.

---

## Shipped Features ✅
- Home: search, governorate chips, KVA + price filters, active filter pills, sort, favorites, unread badge
- Generator detail: photo carousel, call/WhatsApp, booked dates, ratings
- Notifications: realtime, mark-all-read, unread badge
- Profile: rental stats, dark mode (persisted), language toggle (persisted), **avatar photo upload**
- My Rentals: conflict warning, rating badge, view receipt, pull-to-refresh
- Rental Receipt: gradient header, copy-as-text
- Owner Dashboard: requests, history, rate customer, earnings + monthly chart
- Admin panel: company approval, reports, platform stats
- Home screen: **pull-to-refresh**, **"Top Rated" badge** on high-rated generators
- DB migrations 0011–0013 (favorites, notifications, avatar_url)
- CI: flutter.yml with Flutter 3.32.x, analyze+test, APK build job
- CLAUDE.md agentic guide

---

## Remaining Features (priority order)

### NEXT (this loop)
- [ ] iOS Simulator smoke test — confirm app launches and navigates on iOS
- [ ] Generator detail: "Similar generators" horizontal scroll (same governorate, same KVA range)
- [ ] Onboarding splash: 3-page PageView for new installs (how it works for customers)
- [ ] Company profile public page: show company name, logo, rating, all their generators

### SOON
- [ ] Payment flow: COD confirmation screen with digital payment placeholder
- [ ] Chat screen: owner ↔ customer thread per rental request
- [ ] Search autocomplete: as-you-type suggestions from generator titles
- [ ] Generator fuel type filter (diesel/gas/natural gas) — requires migration 0014
- [ ] Push notifications: FCM integration with Supabase edge function
- [ ] Map view: generators plotted on Google Maps
- [ ] Referral code system: users get discount for referring friends
- [ ] Deep linking: share generator page via URL

### DONE-WHEN
- [ ] 80%+ test coverage (current: placeholder only)
- [ ] Web support (currently passkeys SDK error)
- [ ] macOS desktop support
- [ ] Accessibility audit (semantic labels, contrast ratios)

---

## Loop State (updated each iteration)
**Last iteration:** 2026-06-23
**Last commit:** `feat: avatar upload, pull-to-refresh, top rated badge`
**Next action:** iOS simulator test + similar generators section + onboarding splash

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
