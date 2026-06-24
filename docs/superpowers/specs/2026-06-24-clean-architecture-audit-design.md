# AnDaLoeS Clean Architecture Audit — Design Spec

**Date:** 2026-06-24  
**Status:** Approved for implementation

## Goal

Bring the AnDaLoeS Flutter codebase to a state where clean architecture is *actually enforced*, not just structurally present — no Supabase leaking into presentation, no duplicate files, no oversized screens, no repeated shared components.

## Architecture

Flutter 3.44 + Supabase + Riverpod v2. Feature-based with enforced layer boundaries:
- `domain/` — pure Dart entities + abstract repository interfaces (zero Flutter/Supabase imports)
- `data/` — concrete Supabase implementations only
- `presentation/` — screens, widgets, providers (consume domain entities; NEVER import supabase directly)
- `core/` — cross-cutting shared widgets, utils, config, routing, theme

## Sub-projects (run in parallel)

---

### Sub-project A — Dead Code & Duplicate File Cleanup

**Problem:** The migration from `features/x/providers/` → `features/x/presentation/providers/` left the OLD files in place. 12 files exist at both old and new paths. The old paths are still referenced by some imports, creating confusion and risk of divergence.

**Duplicate files to remove (old paths):**
- `features/chat/providers/chat_providers.dart` (→ now in `presentation/providers/`)
- `features/generators/providers/detail_providers.dart`
- `features/generators/providers/generators_providers.dart`
- `features/generators/providers/saved_search_provider.dart`
- `features/notifications/providers/notifications_providers.dart`
- `features/owner_dashboard/providers/owner_providers.dart`
- `features/generators/presentation/home_screen.dart` (→ now in `presentation/screens/`)
- `features/generators/presentation/generator_detail_screen.dart`
- `features/generators/presentation/map_screen.dart`
- `features/notifications/data/notifications_repository.dart` (→ now in `data/repositories/`)
- `features/company/data/company_repository.dart`
- `features/company/data/company.dart`
- `features/rental_request/data/rental_repository.dart` (barrel file remains valid — check)

**Approach:** For each duplicate, verify the NEW path is the canonical one (check imports), fix all callers to import from new path, then delete the old file. Run `flutter analyze` after each deletion.

**Success criteria:** Zero duplicate filenames in the feature tree. All imports resolved to canonical paths. 0 analyze errors.

---

### Sub-project B — Data Layer Purity (Supabase out of Presentation)

**Problem:** 20 files in `presentation/` and `providers/` call `supabase.` directly. This breaks the clean architecture contract — screens are coupled to the database client, untestable, and leak infrastructure concerns into UI code.

**Files violating the contract (direct supabase calls in presentation):**
- `owner_dashboard/presentation/edit_generator_screen.dart`
- `owner_dashboard/presentation/add_generator_screen.dart`
- `owner_dashboard/presentation/owner_dashboard_screen.dart`
- `owner_dashboard/presentation/owner_earnings_screen.dart`
- `owner_dashboard/presentation/providers/owner_providers.dart`
- `owner_dashboard/presentation/widgets/request_card.dart`
- `owner_dashboard/presentation/widgets/thin_supply_nudge.dart`
- `owner_dashboard/presentation/widgets/owner_generators_tab.dart`
- `owner_dashboard/presentation/widgets/owner_requests_tab.dart`
- `chat/presentation/chat_screen.dart`
- `auth/presentation/email_login_screen.dart`
- `auth/presentation/login_screen.dart`
- `auth/presentation/email_auth_screen.dart`
- `auth/presentation/providers/auth_providers.dart`
- `rental_request/presentation/rental_receipt_screen.dart`
- `rental_request/presentation/rental_offer_screen.dart`
- `rental_request/presentation/providers/rental_providers.dart`
- `rental_request/presentation/my_rentals_screen.dart`
- `rental_request/presentation/invoice_screen.dart`

**Approach:** For each file, extract the raw Supabase call into the appropriate `data/repositories/` class, expose it through the domain interface, and update the provider/widget to call the repository instead.

Auth is a special case — `supabase.auth.*` calls in login screens are acceptable at the repository level; the screens should call `authRepository.signIn()` not `supabase.auth.signInWithPassword()` directly.

**Success criteria:** Zero `supabase.` imports in any `presentation/` file. All queries go through repository methods. Providers use `ref.read(xRepositoryProvider).method()`.

---

### Sub-project C — Shared Components + Oversized Screens + Performance

**Problem 1 — Missing shared component library:**  
`core/widgets/` has only 2 files. `CircularProgressIndicator`, `SnackBar`, `AlertDialog` are duplicated inline across 42 files with no consistency. Material 3 tokens not applied uniformly.

**Shared components to extract to `core/widgets/`:**
- `AppLoadingIndicator` — centered CircularProgressIndicator with standard sizing
- `AppSnackBar` — floating SnackBar with rounded corners, success/error/info variants
- `AppConfirmDialog` — AlertDialog with title/body/cancel/confirm, Material 3 style
- `AppStatusBadge` — colored pill chip (replaces inline status badge in 8+ files)
- `AppEmptyState` — icon + title + subtitle + optional CTA (replaces 5 inline empty states)
- `AppSectionHeader` — row with label + optional "see all" action

**Problem 2 — Oversized screens (all over 800-line hard limit):**
- `profile_screen.dart` (1584 lines) → split into sections
- `home_screen.dart` (1336 lines + 772 line duplicate) → consolidate + split
- `generator_detail_screen.dart` (1014 lines × 2 copies) → deduplicate + split
- `my_rentals_widgets.dart` (1160 lines) → split rental card + timeline + actions
- `edit_generator_screen.dart` (840 lines) → extract form sections
- `owner_earnings_screen.dart` (809 lines) → extract chart + stats
- `request_card.dart` (799 lines) → extract action sections

**Problem 3 — Performance gaps:**
- 16 `ListView.builder` calls without `itemExtent` or `addRepaintBoundaries: false`
- Missing `cached_network_image` for generator photos (re-fetched on every scroll)
- `const` missing on dozens of static widgets (extra unnecessary rebuilds)
- No `RepaintBoundary` around heavy chart widgets in owner_earnings_screen

**Success criteria:** 
- `core/widgets/` has 6+ reusable shared components used consistently
- No screen file exceeds 500 lines (400 target)
- All network images use `CachedNetworkImage`
- `flutter analyze` → 0 errors
- `const` audit passes (no obvious missing consts on static widgets)

---

## Global Constraints

- `flutter analyze --no-fatal-infos` → 0 errors after EVERY task
- Branch: `development`
- No new user-facing strings (pure refactor)
- NEVER commit `app/lib/l10n/app_localizations*.dart`
- Keep all public provider variable names identical
- All 3 sub-projects run in parallel (disjoint file sets per sub-project)
- `withValues(alpha:)` not `.withOpacity()`
- `Set.from()` not spread cascade
