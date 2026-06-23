# AnDaLoeS App — Development Goal

**Vision:** Production-ready Egyptian generator rental marketplace.

---

## Shipped Features ✅
- Home: search, governorate chips, KVA + price filters, fuel type filter, search autocomplete, active filter pills, sort, favorites (haptic), unread badge, pull-to-refresh, "Top Rated" badge, fuel type chip on cards
- Generator detail: photo carousel, call/WhatsApp, booked dates, ratings, similar generators horizontal scroll, haptic on Rent Now, favorite FAB
- Notifications: realtime, mark-all-read, unread badge
- Profile: rental stats, dark mode (persisted), language toggle (persisted), avatar photo upload (FilePicker → Supabase avatars bucket)
- My Rentals: conflict warning, rating badge, view receipt, owner accept/reject note shown to customer
- Rental Receipt: gradient header, copy-as-text
- Owner Dashboard: requests, history, rate customer, earnings + monthly chart, accept/reject with optional message dialog
- Add Generator + Edit Generator: fuel type dropdown (diesel/petrol/gas/natural_gas/solar)
- Admin panel: company approval, reports, platform stats
- Company profile: stat chips (generator count, completed rentals)
- DB migrations 0011–0015 (favorites, notifications, avatar, fuel_type, owner_note)
- CI: flutter.yml with Flutter 3.32.x, analyze+test, APK build job
- CLAUDE.md agentic guide
- /goal + /loop skills for self-sustaining development across context windows
- Onboarding splash: 3-page PageView, SharedPreferences flag, first-launch only

---

## Remaining Features (priority order)

### NEXT (this loop)
- [ ] Payment flow: COD confirmation screen with digital payment placeholder
- [ ] Rental request: calendar date range picker (replace plain text fields) with booked dates blocked
- [ ] Chat screen: owner ↔ customer thread per rental request (Supabase Realtime)
- [ ] Generator detail: booked dates from rental_requests shown as unavailable day dots

### SOON
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
**Last commit:** `feat: owner accept/reject with note, fuel type chip on cards, fuel type in forms`
**iOS local constraint:** ios/ is gitignored. After fresh checkout: set IPHONEOS_DEPLOYMENT_TARGET=16.0 in Podfile + xcodeproj, run pod install
**Next action:** COD payment screen + calendar date range picker for rental request

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
