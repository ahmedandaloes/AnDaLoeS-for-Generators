# AnDaLoeS for Generators — Claude Code Instructions

## Project Overview
Egyptian generator rental marketplace. Owners list generators; customers browse, request rentals, and get matched. Built with Flutter + Supabase.

## Stack
- **Flutter** 3.44.3, Dart SDK `>=3.4.0 <4.0.0`, Material 3
- **Supabase** Flutter v2 (`supabase_flutter: ^2.5.6`), project ID `vpfhxxpqkxkucywodpaa`
- **State management**: Riverpod v2 (FutureProvider, StateProvider, NotifierProvider)
- **Routing**: GoRouter `^14.2.0`
- **Key packages**: shared_preferences, share_plus, url_launcher, file_picker, go_router

## Repository Layout
```
app/                        ← Flutter app (working directory for flutter commands)
  lib/
    core/
      config/               ← supabase.dart (client singleton)
      localization/         ← locale_provider.dart (persisted)
      routing/              ← app_router.dart (all GoRouter routes)
      theme/                ← app_theme.dart, theme_mode_provider.dart (persisted)
    features/
      admin/                ← Admin panel (companies, reports, stats tabs)
      auth/                 ← Login, email login, anon guest sign-in
      company/              ← Company onboarding, company profile
      generators/           ← HomeScreen (browse/search/filter), GeneratorDetailScreen
      notifications/        ← NotificationsScreen + realtime + unreadCountProvider
      owner_dashboard/      ← OwnerDashboard, AddGenerator, EditGenerator, OwnerEarnings
      profile/              ← ProfileScreen (stats, dark mode toggle, language)
      ratings/              ← RateRentalScreen
      rental_request/       ← RentalRequestScreen, MyRentals, RentalReceiptScreen
      reports/              ← ReportScreen
  android/                  ← gitignored; AndroidManifest has tel/https intent queries locally
supabase/
  migrations/               ← SQL migrations 0001–0012
```

## Running the App
```bash
cd app
flutter run -d <device-id>    # List devices: flutter devices
flutter analyze --no-fatal-infos   # Zero errors/warnings required
flutter build apk --debug --no-pub # Full compile check
```

## Agentic Development Process

### Before implementing any feature:
1. **Research first** — use `mcp__claude_ai_Context7` for Flutter/Supabase API docs
2. **Plan** — use `planner` agent for non-trivial features
3. **Check existing code** — grep for related providers/widgets before creating new ones
4. **Apply migrations via MCP** — use `mcp__claude_ai_Supabase__apply_migration` for DB changes

### Code rules:
- **All state immutable**: use `Set<String>.from(current)` not spread cascade
- **`withValues(alpha:)`** not deprecated `.withOpacity()`
- **`publishableKey:`** not deprecated `anonKey:` in Supabase.initialize
- **Defer widget-tree-affecting state changes**: wrap in `WidgetsBinding.instance.addPostFrameCallback`
- **Never mutate providers mid-build**: always in callbacks, never in `build()`
- File max 800 lines; features stay in their own `features/` subdirectory

### After writing code:
1. Run `flutter analyze --no-fatal-infos` — must be zero errors
2. Use `code-reviewer` agent
3. Commit with conventional commits format (`feat:`, `fix:`, `chore:` etc.)
4. Push to `claude/quirky-turing-tsb4mk` → `main`

### Testing on device:
```bash
adb devices                                    # List connected devices
adb -s <device> shell screencap -p /sdcard/s.png && adb -s <device> pull /sdcard/s.png /tmp/s.png
adb -s <device> shell uiautomator dump /sdcard/ui.xml && adb -s <device> pull /sdcard/ui.xml /tmp/ui.xml
# Parse ui.xml for exact tap coordinates — do NOT guess from screenshot pixel positions
```

## Database Schema (Supabase)
Key tables (all have RLS):
- `profiles` — id (= auth.uid), full_name, phone, role
- `companies` — id, owner_user_id, name, status (pending/approved/rejected)
- `generators` — id, company_id, title, capacity_kva, price_per_day, city, governorate, status, photos[], avg_score, rating_count
- `rental_requests` — id, generator_id, company_id, customer_id, start_date, end_date, total_days, price_total, status, note
- `ratings` — id, rental_request_id, rater_id, ratee_id, score, comment
- `user_favorites` — user_id, generator_id (UNIQUE pair)
- `notifications` — user_id, type, title, body, is_read, rental_request_id
- `commissions` — rental_request_id, commission_amount, type, value, status
- `reports` — reporter_id, entity_type, entity_id, reason, details

## Auth Flow
- Anonymous guest → can browse, prompted to sign in for requests
- Email/password dev login at `/dev-login`
- Supabase auth with GoRouter redirect guard
- Protected routes: `/profile`, `/my-rentals`, `/owner-dashboard`, `/company/onboard`, `/admin`, `/notifications`, `/rate/:id`, `/receipt/:id`, `/report`

## Available MCP Servers
- `mcp__claude_ai_Supabase__*` — apply_migration, execute_sql, get_logs, list_tables, generate_typescript_types
- `mcp__claude_ai_Context7__*` — query-docs for Flutter, Riverpod, GoRouter, Supabase docs

## Available Agents
Use these proactively — don't just code, orchestrate:
- `planner` — before any multi-file feature
- `code-reviewer` — after every change
- `tdd-guide` — for new features (write tests first)
- `security-reviewer` — before any auth/input-handling change
- `build-error-resolver` — if `flutter analyze` shows errors
- `database-reviewer` — before any Supabase migration

## Known Issues / Constraints
- `android/` is gitignored — AndroidManifest intent queries (tel:, https:) applied locally only; must be re-applied after fresh checkout
- `SegmentedButton.onSelectionChanged` must use `addPostFrameCallback` when changing providers that rebuild MaterialApp (theme/locale)
- `Set<String>` spread cascade `{...set}..remove(x)` causes Dart parse error — use `Set.from()` instead
- Supabase Realtime uses `onPostgresChanges` not deprecated `on()`
