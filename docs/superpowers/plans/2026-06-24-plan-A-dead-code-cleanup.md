# Plan A: Dead Code & Duplicate File Cleanup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the 9 duplicate old-path files left over from the clean-architecture migration and verify zero import regressions.

**Architecture:** Pure deletion. The canonical copies are already at `presentation/screens/` and `presentation/providers/`. Verify every consumer imports the new path, then delete the old file, then run `flutter analyze`.

**Tech Stack:** Flutter 3.44, Dart, bash grep

## Global Constraints

- Working directory: `/Users/andaloes/AnDaLoeS-for-Generators/app`
- Branch: `development`
- `flutter analyze --no-fatal-infos` → 0 errors after EVERY deletion batch
- Never commit generated l10n files (`app_localizations*.dart`)
- Commit format: `chore: remove duplicate <name> from old migration path`

---

### Task 1: Remove duplicate provider files (6 files)

**Files to delete:**
- `lib/features/chat/providers/chat_providers.dart`
- `lib/features/generators/providers/generators_providers.dart`
- `lib/features/generators/providers/detail_providers.dart`
- `lib/features/generators/providers/saved_search_provider.dart`
- `lib/features/notifications/providers/notifications_providers.dart`
- `lib/features/owner_dashboard/providers/owner_providers.dart`

**Canonical new paths:**
- `lib/features/chat/presentation/providers/chat_providers.dart`
- `lib/features/generators/presentation/providers/generators_providers.dart`
- `lib/features/generators/presentation/providers/detail_providers.dart`
- `lib/features/generators/presentation/providers/saved_search_provider.dart`
- `lib/features/notifications/presentation/providers/notifications_providers.dart`
- `lib/features/owner_dashboard/presentation/providers/owner_providers.dart`

- [ ] **Step 1: Verify no file imports the old paths**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
grep -r "features/chat/providers/chat_providers" lib --include="*.dart"
grep -r "features/generators/providers/" lib --include="*.dart"
grep -r "features/notifications/providers/" lib --include="*.dart"
grep -r "features/owner_dashboard/providers/owner_providers" lib --include="*.dart"
```

Expected: no output for each command. If any import found, fix it to point to the new `presentation/providers/` path before deleting.

- [ ] **Step 2: Delete the 6 old provider files**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
rm lib/features/chat/providers/chat_providers.dart
rm lib/features/generators/providers/generators_providers.dart
rm lib/features/generators/providers/detail_providers.dart
rm lib/features/generators/providers/saved_search_provider.dart
rm lib/features/notifications/providers/notifications_providers.dart
rm lib/features/owner_dashboard/providers/owner_providers.dart
```

- [ ] **Step 3: Remove now-empty provider directories**

```bash
rmdir lib/features/chat/providers 2>/dev/null || true
rmdir lib/features/generators/providers 2>/dev/null || true
rmdir lib/features/notifications/providers 2>/dev/null || true
rmdir lib/features/owner_dashboard/providers 2>/dev/null || true
```

- [ ] **Step 4: Analyze**

```bash
flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "chore: remove 6 duplicate provider files from old migration paths"
```

---

### Task 2: Remove duplicate presentation screen files (3 files)

The canonical screens are at `presentation/screens/`. The old files at `presentation/` root are stale.

**Files to delete:**
- `lib/features/generators/presentation/home_screen.dart` (1336 lines — old bloated copy)
- `lib/features/generators/presentation/generator_detail_screen.dart` (1014 lines — exact copy)
- `lib/features/generators/presentation/map_screen.dart`

**Canonical new paths:**
- `lib/features/generators/presentation/screens/home_screen.dart` (772 lines — already split)
- `lib/features/generators/presentation/screens/generator_detail_screen.dart`
- `lib/features/generators/presentation/screens/map_screen.dart`

- [ ] **Step 1: Verify no file imports the old paths**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
grep -rn "features/generators/presentation/home_screen" lib --include="*.dart" | grep -v "presentation/screens"
grep -rn "features/generators/presentation/generator_detail_screen" lib --include="*.dart" | grep -v "presentation/screens"
grep -rn "features/generators/presentation/map_screen" lib --include="*.dart" | grep -v "presentation/screens"
```

Expected: no output. If any hit found — open `lib/core/routing/app_router.dart` and update the import to `presentation/screens/<file>.dart`.

- [ ] **Step 2: Delete old files**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
rm lib/features/generators/presentation/home_screen.dart
rm lib/features/generators/presentation/generator_detail_screen.dart
rm lib/features/generators/presentation/map_screen.dart
```

- [ ] **Step 3: Check for old home_widgets.dart at wrong level**

```bash
ls lib/features/generators/presentation/widgets/
wc -l lib/features/generators/presentation/widgets/home_widgets.dart 2>/dev/null || echo "not found"
```

If `home_widgets.dart` exists at `presentation/widgets/` AND also at `presentation/screens/widgets/` or similar, keep only the one imported by the canonical `screens/home_screen.dart`. Delete the unused copy.

- [ ] **Step 4: Analyze**

```bash
flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "chore: remove 3 duplicate screen files from old pre-screens/ paths"
```

---

### Task 3: Verify router imports canonical paths + push

- [ ] **Step 1: Confirm app_router.dart uses canonical paths**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
grep -n "import.*generators\|import.*notifications\|import.*chat" lib/core/routing/app_router.dart | grep -v "presentation/screens\|presentation/providers\|presentation/widgets"
```

Any hit that points to a non-canonical path: open the file and fix the import to use `presentation/screens/<name>.dart`.

- [ ] **Step 2: Final analyze**

```bash
flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 3: Push**

```bash
git push origin development
```
