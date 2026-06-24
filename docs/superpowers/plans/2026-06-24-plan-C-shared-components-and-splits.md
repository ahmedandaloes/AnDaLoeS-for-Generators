# Plan C: Shared Components + Oversized Screen Splits + Performance

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `core/widgets/` shared component library (6 components), split 7 oversized screen files to under 500 lines each, and fix performance gaps (const widgets, ListView keys, CachedNetworkImage).

**Architecture:** Extract duplicated UI patterns into `core/widgets/AppXxx` classes. Oversized screens get sub-widget files extracted into their feature's `presentation/widgets/` directory. CachedNetworkImage replaces all `Image.network` / `NetworkImage`. All static subtrees get `const`.

**Tech Stack:** Flutter 3.44, Material 3, cached_network_image (already in pubspec)

## Global Constraints

- Working directory: `/Users/andaloes/AnDaLoeS-for-Generators/app`
- Branch: `development`
- `flutter analyze --no-fatal-infos` → 0 errors after EVERY task
- `withValues(alpha:)` not `.withOpacity()`
- `Set.from()` not spread cascade
- `const` on every static widget that allows it
- File max 500 lines target, 800 hard limit
- Never commit generated l10n files
- No new user-facing strings — this is pure refactor
- Commit format: `refactor(core): add AppXxx shared widget` / `refactor(<feature>): split oversized screen`

---

### Task 1: Shared component — AppLoadingIndicator + AppErrorState (already exists, add missing)

**Files:**
- Create: `lib/core/widgets/app_loading_indicator.dart`
- Create: `lib/core/widgets/app_status_badge.dart`
- Create: `lib/core/widgets/app_empty_state.dart`
- `lib/core/widgets/app_error_state.dart` already exists — no changes needed

- [ ] **Step 1: Create AppLoadingIndicator**

Create `lib/core/widgets/app_loading_indicator.dart`:

```dart
import 'package:flutter/material.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create AppStatusBadge**

Create `lib/core/widgets/app_status_badge.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/status_colors.dart';

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({super.key, required this.status, this.fontSize = 11});

  final String status;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = generatorStatusColor(status, cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create AppEmptyState**

Create `lib/core/widgets/app_empty_state.dart`:

```dart
import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title,
                style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(onPressed: action, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/
git commit -m "refactor(core): add AppLoadingIndicator, AppStatusBadge, AppEmptyState shared widgets"
```

---

### Task 2: Shared component — AppSnackBar + AppConfirmDialog

**Files:**
- Create: `lib/core/widgets/app_snack_bar.dart`
- Create: `lib/core/widgets/app_confirm_dialog.dart`

- [ ] **Step 1: Create AppSnackBar**

Create `lib/core/widgets/app_snack_bar.dart`:

```dart
import 'package:flutter/material.dart';

enum SnackVariant { success, error, info }

class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    SnackVariant variant = SnackVariant.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (variant) {
      SnackVariant.success => (cs.primaryContainer, cs.onPrimaryContainer),
      SnackVariant.error => (cs.errorContainer, cs.onErrorContainer),
      SnackVariant.info => (cs.surfaceContainerHighest, cs.onSurface),
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: fg)),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: duration,
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, variant: SnackVariant.success);

  static void error(BuildContext context, String message) =>
      show(context, message, variant: SnackVariant.error);
}
```

- [ ] **Step 2: Create AppConfirmDialog**

Create `lib/core/widgets/app_confirm_dialog.dart`:

```dart
import 'package:flutter/material.dart';

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.destructive = false,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: Text(body),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: cs.error)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/
git commit -m "refactor(core): add AppSnackBar and AppConfirmDialog shared widgets"
```

---

### Task 3: Replace inline snackbars + loading indicators — owner_dashboard

Replace 5 most-duplicated usages in owner_dashboard to validate the pattern before mass-replacing.

**Files to modify:**
- `lib/features/owner_dashboard/presentation/add_generator_screen.dart`
- `lib/features/owner_dashboard/presentation/edit_generator_screen.dart`

- [ ] **Step 1: Find all showSnackBar calls in these two files**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
grep -n "showSnackBar\|CircularProgressIndicator" \
  lib/features/owner_dashboard/presentation/add_generator_screen.dart \
  lib/features/owner_dashboard/presentation/edit_generator_screen.dart
```

- [ ] **Step 2: Replace each SnackBar pattern**

Add import to each file:
```dart
import '../../../../core/widgets/app_snack_bar.dart';
```

Replace every block like:
```dart
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text('some message'),
  backgroundColor: Theme.of(context).colorScheme.error,
));
```

With:
```dart
AppSnackBar.error(context, 'some message');
```

And success variants:
```dart
AppSnackBar.success(context, 'Generator saved');
```

- [ ] **Step 3: Replace CircularProgressIndicator patterns**

Add import:
```dart
import '../../../../core/widgets/app_loading_indicator.dart';
```

Replace:
```dart
Center(child: CircularProgressIndicator())
```
With:
```dart
const AppLoadingIndicator()
```

- [ ] **Step 4: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner_dashboard/
git commit -m "refactor(owner_dashboard): use AppSnackBar and AppLoadingIndicator shared widgets"
```

---

### Task 4: Split profile_screen.dart (1584 lines → 4 files)

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart` (keep to ~350 lines)
- Create: `lib/features/profile/presentation/widgets/profile_stats_section.dart`
- Create: `lib/features/profile/presentation/widgets/profile_settings_section.dart`
- Create: `lib/features/profile/presentation/widgets/profile_referral_card.dart`

- [ ] **Step 1: Identify sections in profile_screen.dart**

```bash
grep -n "^class \|Widget _build\|// ===" \
  lib/features/profile/presentation/profile_screen.dart
```

- [ ] **Step 2: Extract _StatItem, _StatDivider, _SessionRow to profile_stats_section.dart**

Read lines ~1300–1370 of `profile_screen.dart`. Move `_StatItem`, `_StatDivider`, and any stats-related builder methods to:

Create `lib/features/profile/presentation/widgets/profile_stats_section.dart`:

```dart
import 'package:flutter/material.dart';

class ProfileStatsSection extends StatelessWidget {
  const ProfileStatsSection({
    super.key,
    required this.rentalCount,
    required this.favoriteCount,
    required this.rating,
  });

  final int rentalCount;
  final int favoriteCount;
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(value: rentalCount.toString(), label: 'Rentals'),
        const _StatDivider(),
        _StatItem(value: favoriteCount.toString(), label: 'Saved'),
        const _StatDivider(),
        _StatItem(value: rating.toStringAsFixed(1), label: 'Rating'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;
  // [paste the existing _StatItem build() body from profile_screen.dart here]
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: VerticalDivider(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}
```

**NOTE:** Read the actual existing `_StatItem` and `_StatDivider` build methods from `profile_screen.dart` lines ~1300–1345 and use those exact implementations — the above is a template.

- [ ] **Step 3: Extract _EditablePhoneRow, _SectionLabel, _Card, _InfoRow to profile_settings_section.dart**

Create `lib/features/profile/presentation/widgets/profile_settings_section.dart` containing:
- `_EditablePhoneRow` (from lines ~1371–1424)
- `_SectionLabel` (from lines ~1425–1445)
- `_Card` (from lines ~1446–1457)
- `_InfoRow` (from lines ~1458–1486)

Read those line ranges from `profile_screen.dart` exactly and move them to this new file. Add `import 'package:flutter/material.dart';` at the top.

- [ ] **Step 4: Extract _ReferralCard to profile_referral_card.dart**

Create `lib/features/profile/presentation/widgets/profile_referral_card.dart`:
Move `_ReferralCard` (from lines ~1487–end of file).

- [ ] **Step 5: Update profile_screen.dart imports and remove extracted classes**

In `profile_screen.dart`:
1. Add imports:
```dart
import 'widgets/profile_stats_section.dart';
import 'widgets/profile_settings_section.dart';
import 'widgets/profile_referral_card.dart';
```
2. Delete the class definitions that were moved (lines ~1300–end)
3. Replace any inline usage with the extracted widget class names

- [ ] **Step 6: Verify line count**

```bash
wc -l lib/features/profile/presentation/profile_screen.dart
wc -l lib/features/profile/presentation/widgets/profile_stats_section.dart
wc -l lib/features/profile/presentation/widgets/profile_settings_section.dart
```

Each file must be under 500 lines.

- [ ] **Step 7: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/profile/
git commit -m "refactor(profile): split 1584-line profile_screen into 4 focused files"
```

---

### Task 5: Split generator_detail_screen.dart (1014 lines → 4 files)

**Files:**
- Modify: `lib/features/generators/presentation/screens/generator_detail_screen.dart`
- Create: `lib/features/generators/presentation/widgets/generator_specs_section.dart`
- Create: `lib/features/generators/presentation/widgets/generator_photos_carousel.dart`
- Create: `lib/features/generators/presentation/widgets/generator_action_bar.dart`

- [ ] **Step 1: Audit sections in generator_detail_screen.dart**

```bash
grep -n "^class \|Widget _build\|// ---" \
  lib/features/generators/presentation/screens/generator_detail_screen.dart | head -30
```

- [ ] **Step 2: Extract photo carousel**

Find the photo gallery/carousel widget section (typically ~80–150 lines). Move it to:

`lib/features/generators/presentation/widgets/generator_photos_carousel.dart`:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/app_loading_indicator.dart';

class GeneratorPhotosCarousel extends StatefulWidget {
  const GeneratorPhotosCarousel({super.key, required this.photos});
  final List<String> photos;
  @override
  State<GeneratorPhotosCarousel> createState() => _GeneratorPhotosCarouselState();
}

class _GeneratorPhotosCarouselState extends State<GeneratorPhotosCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        height: 220,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.bolt_rounded, size: 80),
      );
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: widget.photos[i],
              fit: BoxFit.cover,
              placeholder: (_, __) => const AppLoadingIndicator(),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photos.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _current ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

**NOTE:** Read the existing photo section from `generator_detail_screen.dart` and use its actual implementation — the above is a reference template showing the `CachedNetworkImage` migration pattern.

- [ ] **Step 3: Extract specs section (capacity, fuel, accessories, hire_type)**

Move to `lib/features/generators/presentation/widgets/generator_specs_section.dart`.
Pattern:
```dart
import 'package:flutter/material.dart';
import '../../domain/entities/generator.dart';

class GeneratorSpecsSection extends StatelessWidget {
  const GeneratorSpecsSection({super.key, required this.generator});
  final GeneratorEntity generator;
  @override
  Widget build(BuildContext context) {
    // move the specs grid/rows from detail screen here
  }
}
```

- [ ] **Step 4: Extract action bar (book button, favorite, share)**

Move to `lib/features/generators/presentation/widgets/generator_action_bar.dart`.

- [ ] **Step 5: Update generator_detail_screen.dart to use extracted widgets**

Add imports and replace inline sections with the extracted widget class names.

- [ ] **Step 6: Verify line count**

```bash
wc -l lib/features/generators/presentation/screens/generator_detail_screen.dart
```

Must be under 500 lines.

- [ ] **Step 7: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/generators/presentation/
git commit -m "refactor(generators): split 1014-line detail screen into 4 focused files"
```

---

### Task 6: Split my_rentals_widgets.dart (1160 lines → 3 files)

**Files:**
- Modify: `lib/features/rental_request/presentation/widgets/my_rentals_widgets.dart`
- Create: `lib/features/rental_request/presentation/widgets/rental_card.dart`
- Create: `lib/features/rental_request/presentation/widgets/rental_timeline_widget.dart`

- [ ] **Step 1: Audit sections**

```bash
grep -n "^class " \
  lib/features/rental_request/presentation/widgets/my_rentals_widgets.dart
```

- [ ] **Step 2: Move RentalCard to rental_card.dart**

Create `lib/features/rental_request/presentation/widgets/rental_card.dart`.
Move the `RentalCard` class (and its private helper classes) there.
Update `my_rentals_widgets.dart` to export from the new file:
```dart
export 'rental_card.dart' show RentalCard;
```

- [ ] **Step 3: Move _StatusTimeline to rental_timeline_widget.dart**

Create `lib/features/rental_request/presentation/widgets/rental_timeline_widget.dart`.
Move `_StatusTimeline` (or the timeline ConsumerWidget). Rename to `RentalTimelineWidget` (public).
Export from `my_rentals_widgets.dart`:
```dart
export 'rental_timeline_widget.dart' show RentalTimelineWidget;
```

- [ ] **Step 4: Verify line counts**

```bash
wc -l \
  lib/features/rental_request/presentation/widgets/my_rentals_widgets.dart \
  lib/features/rental_request/presentation/widgets/rental_card.dart \
  lib/features/rental_request/presentation/widgets/rental_timeline_widget.dart
```

Each must be under 500 lines.

- [ ] **Step 5: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/rental_request/presentation/widgets/
git commit -m "refactor(rental_request): split 1160-line my_rentals_widgets into 3 files"
```

---

### Task 7: Performance — CachedNetworkImage everywhere + const pass

**Files:** Any file using `Image.network` or `NetworkImage(` or `FadeInImage`

- [ ] **Step 1: Find all non-cached image usages**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
grep -rn "Image\.network\|NetworkImage(\|FadeInImage" lib/features --include="*.dart"
```

- [ ] **Step 2: Verify cached_network_image is in pubspec**

```bash
grep "cached_network_image" pubspec.yaml
```

If missing, add it:
```bash
flutter pub add cached_network_image
```

- [ ] **Step 3: Replace each Image.network with CachedNetworkImage**

Pattern — replace:
```dart
Image.network(url, fit: BoxFit.cover)
```
With:
```dart
CachedNetworkImage(
  imageUrl: url,
  fit: BoxFit.cover,
  placeholder: (context, url) => const AppLoadingIndicator(),
  errorWidget: (context, url, error) =>
      const Icon(Icons.broken_image_rounded),
)
```

Add `import 'package:cached_network_image/cached_network_image.dart';` to each modified file.

- [ ] **Step 4: Add missing const to static widgets**

```bash
flutter analyze --no-fatal-infos 2>&1 | grep "prefer_const_constructors"
```

For each reported line, add `const` keyword before the widget constructor.

- [ ] **Step 5: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib/
git commit -m "perf: replace Image.network with CachedNetworkImage and add missing const widgets"
git push origin development
```
