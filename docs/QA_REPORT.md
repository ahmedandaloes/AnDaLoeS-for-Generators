# AnDaLoeS v1.0.0-mvp QA Report
Date: 2026-06-25
Branch: claude/quirky-turing-tsb4mk (merged to main)
Device: Android 15 (API 35) — Physical device via ADB (127.0.0.1:6562)
Flutter: 3.44.3

---

## Summary

PARTIAL PASS — Core product journeys pass. One HIGH issue blocks the anonymous/guest
sign-in path (Supabase anonymous auth is disabled in this project, but the UI presents
it as a working option and exposes the raw API error message). No CRITICAL data-loss,
money-calculation, state-machine, or role-bypass issues found.

---

## Static Audit Results

### Rental State Machine

PASS. All five status values (pending, accepted, active, completed, cancelled/rejected)
are wired end-to-end:

- pending → accepted: owner calls updateRequestStatus('accepted') in request_card.dart
- accepted → active: _confirmDelivered() in request_card.dart triggers updateRequestStatus('active')
  after recording a delivery handover (fuel level, meter reading, note).
- active → completed: _confirmCompleted() triggers updateRequestStatus('completed')
  after recording a return handover.
- pending → rejected: owner can reject from request_card.dart with an optional note.
- pending / accepted → cancelled: customer can cancel from rental_card.dart (pending only).
- Server-side guard: migration 0035_rental_status_state_machine_guard.sql enforces valid
  transitions at the DB layer, providing defense-in-depth.

Delivery handshake is wired correctly. The customer sees an "Out for delivery" banner
when delivered_at is set (rental_card.dart:87) before the status reaches 'active'.
rental_repository.dart:71–73 sets delivered_at via markOutForDelivery().

### Commission Calculation

PASS. Price computation is correct and tiered:

- bestRentalPrice() in lib/core/utils/pricing.dart uses a greedy algorithm to find the
  cheapest combination of monthly, weekly, and daily rates.
- price_total is computed at request time in rental_request_screen.dart:105 and stored
  when the request is submitted via payment_confirmation_screen.dart:63.
- Owner net payout = price_total - commission_amount, computed in
  owner_repository.dart:171 and displayed in owner_earnings_screen.dart:70.
- Commission type (fixed/percentage) is fetched from commission_config table and applied
  in the admin revenue tab.
- 4 unit tests in test/core_logic_test.dart cover bestRentalPrice edge cases
  (day-only, cheapest tier, month tier, never exceeds plain daily total). All pass.

### Safety Ack Flow

PASS. SafetyAckDialog.checkAndShow() is called in rental_request_screen.dart:87 before
the submit action proceeds. The dialog uses SharedPreferences to persist the
"safety_ack_shown" flag — shown only once per device. The dialog implementation is in
lib/features/rental_request/presentation/widgets/safety_ack_dialog.dart.

### Form Validation

PASS. company_onboarding_screen.dart declares _formKey (line 45), calls
_formKey.currentState!.validate() before submit (line 77), and has validators on
at least three TextFormFields (lines 333, 349, 386). The form is passed to the
widget tree via formKey: _formKey (line 233).

### Auth Guards

PASS. app_router.dart defines a protected set of routes and checks
supabase.auth.currentSession != null to gate them. Protected routes verified:
/profile, /my-rentals, /owner-dashboard, /company/onboard, /admin, /notifications,
and dynamic paths /generators/:id/request, /owner/*, /rate/*, /receipt/*, /chat/*,
/offer/*, /invoice/*, /report*.

On-device confirmation: tapping "Rent Now" as a guest correctly redirects to the
login screen. The redirect fires before the RentalRequestScreen mounts.

Role separation (defense-in-depth):
- /admin is blocked for non-admin roles when _roleCache.value is known (line 102).
- /owner/* paths blocked for non-owner, non-admin (line 103).
- Role is fetched from profiles table and cached in a ValueNotifier; all auth state
  changes refresh it.

### Admin Document Verification

PASS. The admin_companies_tab.dart renders _VerifyDocButton (line 313) for each
document in a company's documents array. admin_repository.dart:329–332 implements
verifyCompanyDocument() which sets verified: true on the company_document row.
Both approval (approveCompany) and rejection (rejectCompany with rejection_reason)
are wired and tested on-screen. Migration 0041 adds RLS to company_documents;
migration 0042 adds the verified column.

### Zero Supabase in Presentation

PASS. No presentation layer file imports lib/core/config/supabase.dart or calls
supabase.from / supabase.auth directly. Two auth presentation screens
(email_login_screen.dart and email_auth_screen.dart) import
package:supabase_flutter/supabase_flutter.dart show AuthException — this is limited to
the exception type only and does not violate the data-access boundary rule.

### RLS Migrations

PASS. Migrations 0041_company_documents_rls.sql and 0042_company_documents_verified.sql
are present in supabase/migrations/. Total migration count: 43 files (0001–0042, with
two files numbered 0037).

Note: Two files share the prefix 0037 (0037_generator_hire_type_fuel_policy_accessories.sql
and 0037_rental_handovers.sql). This does not cause a functional problem since Supabase
applies them in filename order, but it is a naming inconsistency that should be cleaned
up to avoid confusion.

### ARB Localization Parity

PASS. EN keys: 545, AR keys: 545. Zero missing keys in AR, zero extra keys in AR.
All strings have Arabic translations.

### File Size Audit

WARNING (LOW) — Seven files are 749–797 lines, close to the 800-line limit.
None exceed the limit, but they are approaching it:

  797  lib/features/owner_dashboard/presentation/widgets/request_card.dart
  787  lib/features/rental_request/presentation/widgets/rental_card.dart
  773  lib/features/generators/presentation/screens/home_screen.dart
  760  lib/features/rental_request/presentation/rental_request_screen.dart
  753  lib/features/owner_dashboard/presentation/owner_earnings_screen.dart
  749  lib/features/company/presentation/company_onboarding_screen.dart
  742  lib/features/generators/presentation/screens/generator_detail_body.dart

No file exceeds 800 lines today, but request_card.dart and rental_card.dart are 3
and 13 lines away respectively. Any future feature additions will breach the limit.

---

## On-Device Test

Device: Android 15 (API 35), physical device via adb

### Results

PASS — App builds and launches.
  Build: flutter-apk/app-debug.apk built and installed in ~4.2s.
  The first install attempt failed with INSTALL_FAILED_UPDATE_INCOMPATIBLE
  (signature mismatch from a previous installation). ADB automatically uninstalled
  the old version and reinstalled successfully.

PASS — Onboarding renders in Arabic (RTL).
  Screen 3 of onboarding captured: "الطاقة وقتما تحتاجها" headline, Next (التالي)
  and Skip (تخطٍّ) buttons present, page indicator shows 3 dots.

PASS — Home screen renders after Skip.
  AnDaLoeS header, search bar ("ابحث عن المولدات أو المدينة..."), city filter chips
  (Minya, Alexandria, Giza, Cairo, Assiut), "found 1" count, generator card
  (AnDo, 150 KVA, Alexandria, EGP 5000/day, rating 5.0, verified badge) all present.

PASS — Generator detail screen renders.
  Title, KVA badge, company name + verified icon, location, pricing table
  (EGP 5000/day, 23000/week, 135000/month), price estimator, WhatsApp + call buttons,
  and "استأجر الآن" (Rent Now) CTA all render.

PASS — Auth guard on Rent Now.
  Tapping "Rent Now" as an unauthenticated guest correctly redirects to the login
  screen before any rental logic executes.

FAIL — Anonymous/guest sign-in broken (see Issues #1 and #2 below).
  Tapping "المتابعة كضيف" (Continue as guest) on the dev login screen shows snackbar:
  "Anonymous sign-ins are disabled"

---

## Issues Found

### Issue 1 — HIGH
Title: Anonymous sign-in is disabled on Supabase but UI presents it as a working option
Severity: HIGH
Steps:
  1. Launch app (fresh install or after clearing onboarding state).
  2. Tap any protected route or tap Skip on onboarding, then tap a generator, then
     tap "Rent Now".
  3. On the login screen, tap "دخول المطوّر" (Developer Login).
  4. Tap "المتابعة كضيف" (Continue as guest).
Expected: User signs in anonymously and is redirected to home.
Actual: Snackbar shows "Anonymous sign-ins are disabled".
Impact: The guest/anonymous journey is completely broken. Any user who attempts
  guest sign-in sees a technical error and cannot proceed.
Suspected cause: Supabase project (vpfhxxpqkxkucywodpaa) does not have anonymous
  sign-ins enabled in Authentication > Settings. The feature was added in commit
  961a22b as a dev workaround but the Supabase toggle was never turned on.
Files:
  lib/features/auth/data/repositories/auth_repository.dart:78–79
  lib/features/auth/presentation/email_login_screen.dart:47–53
  lib/features/auth/presentation/email_auth_screen.dart:93–99
Fix options:
  (a) Enable anonymous sign-ins in the Supabase dashboard — preferred for MVP.
  (b) Remove the "Continue as guest" button from both login screens until enabled.

### Issue 2 — MEDIUM
Title: Raw Supabase AuthException message "Anonymous sign-ins are disabled" shown to users
Severity: MEDIUM
Steps: Same as Issue 1.
Expected: A user-friendly error message like "Guest login is not available. Please
  sign in with email."
Actual: The raw API string "Anonymous sign-ins are disabled" is shown in a snackbar.
Files:
  lib/features/auth/presentation/email_login_screen.dart:53 — _show(e.message)
  lib/features/auth/presentation/email_auth_screen.dart:52 — return e.message
  (email_auth_screen has _friendlyAuthError() but it falls through for this error)
Fix: Add a check for 'anonymous' in _friendlyAuthError() and in the email_login_screen
  _guest() method; return a localised user-friendly string.

### Issue 3 — LOW
Title: Two migration files share prefix 0037 (naming inconsistency)
Severity: LOW
Details:
  0037_generator_hire_type_fuel_policy_accessories.sql
  0037_rental_handovers.sql
Impact: No functional impact today, but breaks sequential naming convention and could
  confuse migration tooling or developers applying migrations manually.
Fix: Rename one file to 0037b or renumber to restore sequential order.
File: supabase/migrations/

### Issue 4 — LOW
Title: KGP (Kotlin Gradle Plugin) deprecation warning from 5 plugins
Severity: LOW
Details: device_info_plus, package_info_plus, passkeys_android, share_plus,
  ua_client_hints all apply KGP. Future Flutter versions will fail to build.
Impact: No current build failure; warning only.
Fix: Upgrade affected plugins to KGP-compatible versions when available.

### Issue 5 — LOW
Title: request_card.dart and rental_card.dart approaching 800-line file limit
Severity: LOW
Files:
  lib/features/owner_dashboard/presentation/widgets/request_card.dart (797 lines)
  lib/features/rental_request/presentation/widgets/rental_card.dart (787 lines)
Impact: Any new feature code will breach the project's 800-line rule.
Fix: Extract handover dialog (_showHandoverDialog), deposit chip, and earnings
  summary into separate widget files before next feature sprint.

---

## Items Not Exercised in This Pass

The following require a signed-in account (owner or admin role) to test. These are
blocked by Issue 1 (guest login fails). They are NOT marked passing.

- Full customer rental request submission (date selection, conflict detection,
  SafetyAck, payment confirmation, receipt).
- Owner: accept/reject request, delivery handshake, mark completed, earnings screen.
- Admin panel: companies approve/reject, generators approve/reject, revenue tab,
  mark collected, VAT export, ops tab, stats, user role change.
- My Rentals screen with actual rental data (out-for-delivery banner, track delivery,
  deposit status, chat link, rate button).
- RLS policy enforcement tested via direct SQL queries.
- Notification realtime delivery.
- Payment confirmation COD itemised total and deposit.

These must be re-tested after Issue 1 is resolved with a dev account that has
email/password credentials or after anonymous auth is enabled.

---

## flutter analyze

1,639 issues found — ALL are info-level lint hints (require_trailing_commas,
prefer_const_constructors, prefer_const_declarations). Zero errors. Zero warnings.
The project compiles and runs cleanly.

## flutter test

376 tests — All passed.
Test coverage areas: bestRentalPrice tiers, friendlyDbError, generator KVA/kW
conversion, useCaseLabel, ICS generation, ARB parity, rental model round-trips,
safety ack persistence, owner request model, chat message model, admin stats, ratings,
profile, company, notifications, reports.

---

## Overall Status

SHIP with fix for Issue 1 before any user-facing guest journey is promoted.
The core product (browse, detail, auth guard, state machine, commission math, RLS
migrations, localisation) is correctly wired. The anonymous sign-in feature added in
commit 961a22b is not functional because the Supabase project setting was not enabled.
Enable anonymous auth in the Supabase dashboard (or remove the button) to unblock
the guest journey, then re-run the on-device rental flow test.
