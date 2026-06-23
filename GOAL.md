# AnDaLoeS App — Development Goal

**Vision:** Production-ready Egyptian generator rental marketplace.

---

## Shipped Features ✅
- Home: search, governorate chips, KVA + price filters, active filter pills, sort, favorites (haptic), unread badge, pull-to-refresh, "Top Rated" badge
- Generator detail: photo carousel, call/WhatsApp, booked dates, ratings, **similar generators horizontal scroll**, **haptic on Rent Now**
- Notifications: realtime, mark-all-read, unread badge
- Profile: rental stats, dark mode (persisted), language toggle (persisted), **avatar photo upload** (FilePicker → Supabase avatars bucket)
- My Rentals: conflict warning, rating badge, view receipt
- Rental Receipt: gradient header, copy-as-text
- Owner Dashboard: requests, history, rate customer, earnings + monthly chart
- Admin panel: company approval, reports, platform stats
- DB migrations 0011–0013 (favorites, notifications, avatar_url + avatars bucket + RLS)
- CI: flutter.yml with Flutter 3.32.x, analyze+test, APK build job
- CLAUDE.md agentic guide
- /goal + /loop skills for self-sustaining development across context windows
- Onboarding splash: 3-page PageView, SharedPreferences flag, first-launch only
- Generator detail: favorite FAB (syncs with Supabase user_favorites), animated icon
- Company profile: stat chips (generator count, completed rentals)

---

## Remaining Features (priority order)

### NEXT (this loop)
- [ ] Search autocomplete: as-you-type suggestions from generator titles/cities
- [ ] Generator fuel type filter (diesel/gas/natural gas) — migration 0014 + UI chip
- [ ] Rental request UX: calendar date range picker (replace text fields)
- [ ] Owner: respond to rental request with message (accept + note to customer)

### SOON
- [ ] Payment flow: COD confirmation screen with digital payment placeholder
- [ ] Chat screen: owner ↔ customer thread per rental request
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
**Last commit:** `feat: onboarding splash, detail favorite button, company stats chips`
**Next action:** Search autocomplete + fuel type filter (migration 0014) + calendar date picker for rental request

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
