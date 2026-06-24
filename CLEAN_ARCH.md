# Clean Architecture Migration Plan

## Target structure per feature

```
features/<feature>/
  data/
    models/        ← pure Dart data classes (fromJson/toJson, no Flutter)
    repositories/  ← concrete Supabase implementations
  domain/
    entities/      ← business objects (no JSON, no Flutter, no Supabase)
    repositories/  ← abstract interfaces (contracts)
  presentation/
    screens/       ← full-page widgets (ConsumerWidget / ConsumerStatefulWidget)
    widgets/       ← reusable sub-widgets within this feature
    providers/     ← Riverpod providers (FutureProvider, NotifierProvider, etc.)
```

Cross-cutting (stays in `lib/core/`):
- `core/config/`       — Supabase singleton, env
- `core/routing/`      — GoRouter, AppRoutes
- `core/theme/`        — AppTheme, status_colors, theme_mode_provider
- `core/widgets/`      — shared widgets (AppErrorState, PressScale, etc.)
- `core/utils/`        — db_error, commission, ics helpers
- `core/localization/` — locale_provider

## Rules
- Entities have NO Supabase/Flutter imports — plain Dart only
- Repositories (domain) are abstract — no Supabase code
- Repository (data) implements domain interface — all Supabase queries here
- Providers reference domain repositories via DI (ref.read(xRepositoryProvider))
- Screens/widgets import only providers and domain entities — never raw Supabase
- File max 400 lines (800 hard limit)
- Every new user-facing string → app_en.arb + app_ar.arb

## Migration status

| Feature | Models | Domain Entity | Domain Repo | Data Repo | Providers | Screens/Widgets |
|---------|--------|---------------|-------------|-----------|-----------|-----------------|
| generators | ❌ | ❌ | ❌ | partial | partial | needs split |
| rental_request | ❌ | ❌ | ❌ | partial | ❌ | needs split |
| owner_dashboard | ❌ | ❌ | ❌ | ❌ | partial | needs split |
| admin | ❌ | ❌ | ❌ | ❌ | ❌ | needs split |
| auth | ❌ | ❌ | ❌ | ❌ | ❌ | needs split |
| company | ❌ | ❌ | ❌ | partial | ❌ | needs split |
| notifications | ❌ | ❌ | ❌ | partial | partial | needs split |
| chat | ❌ | ❌ | ❌ | ❌ | partial | ok |
| profile | ❌ | ❌ | ❌ | ❌ | ❌ | needs split |
| ratings | ❌ | ❌ | ❌ | ❌ | ❌ | ok |
| reports | ❌ | ❌ | ❌ | ❌ | ❌ | ok |

## Migration order (dependency-safe)

1. **generators** — most-referenced; unblocks rental_request + owner_dashboard
2. **rental_request** — depends on generators entity
3. **notifications** — standalone
4. **owner_dashboard** — depends on generators + rental_request
5. **auth** — standalone
6. **company** — depends on auth
7. **admin** — depends on generators + rental_request + company
8. **profile** — standalone
9. **chat** — standalone (small, already close)
10. **ratings / reports** — tiny, last

## Loop rules
- One feature per loop cycle (refactor + verify analyze 0 errors + commit)
- Mark feature row ✅ when done
- Do NOT break existing functionality — providers keep same public API
- Do NOT rename routes or provider variable names (breaking change)
- After each feature: `flutter analyze --no-fatal-infos` must show 0 errors
- Commit: `refactor(<feature>): clean architecture layers`
