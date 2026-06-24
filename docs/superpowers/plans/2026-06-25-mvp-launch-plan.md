# AnDaLoeS MVP Launch Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a production-ready MVP — every user role can complete their core journey end-to-end with no dead ends, no crashes, and no data leaks.

**Architecture:** Flutter 3.44 + Supabase on `development` → merge to `main` → release build (APK + IPA).

**Tech Stack:** Flutter 3.44.3, Dart ≥3.4, Supabase Flutter v2, Riverpod v2, GoRouter ^14, Material 3

## Global Constraints

- `flutter analyze --no-fatal-infos` → 0 errors, 0 warnings after EVERY task
- Branch: `development` until Task 12 (merge to `main`)
- DB changes via `mcp__claude_ai_Supabase__apply_migration` only
- Never commit `app/lib/l10n/app_localizations*.dart`
- DB values stay English (status/role/fuel_type/reason codes)
- `withValues(alpha:)` not `.withOpacity()`
- `Set.from()` not spread cascade
- Every new user-facing string → `app_en.arb` + `app_ar.arb`
- No service_role key in client code — anon/publishable only

---

## Phase 0 — Code Quality Gate (unblock everything else)

### Task 1: Fix remaining RTL hazards (9 files)

**Files to modify:** 9 files with `EdgeInsets.only(left/right)` or `Alignment.centerLeft/Right`

**What:** Replace directional insets/alignments with their `Directional` variants so Arabic RTL layout is correct.

- [ ] **Step 1: Find all violations**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
grep -rn "EdgeInsets\.only(left\|EdgeInsets\.only(right\|Alignment\.centerLeft\|Alignment\.centerRight\|Alignment\.topLeft\|Alignment\.topRight\|Alignment\.bottomLeft\|Alignment\.bottomRight" lib/features --include="*.dart" | grep -v "isMe\|chat_bubble\|intentional"
```

- [ ] **Step 2: Replace each hit**

Pattern:
```dart
// BEFORE
padding: const EdgeInsets.only(left: 16, right: 8)
alignment: Alignment.centerLeft

// AFTER
padding: const EdgeInsetsDirectional.only(start: 16, end: 8)
alignment: AlignmentDirectional.centerStart
```

Exception: chat bubble files where `isMe` intentionally flips sides — leave those.

- [ ] **Step 3: Analyze**

```bash
flutter analyze --no-fatal-infos
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 4: Commit**

```bash
git add lib/
git commit -m "fix(rtl): replace directional EdgeInsets/Alignment with Directional variants"
```

---

### Task 2: Fix raw 'Error: $e' snackbars + clean error UX

**What:** Any `SnackBar(content: Text('Error: $e'))` or `'$e'` leaked to UI must be replaced with `AppSnackBar.error(context, friendlyDbError(e))` or a translated generic message.

- [ ] **Step 1: Find all raw error leaks**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
grep -rn "'\$e'\|\"Error: \$\|'Error: \$\|Text('\$e" lib/features --include="*.dart"
```

- [ ] **Step 2: Replace each with friendly error**

```dart
// BEFORE
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Error: $e')));

// AFTER
import '../../../../core/utils/db_error.dart';
import '../../../../core/widgets/app_snack_bar.dart';
// ...
AppSnackBar.error(context, friendlyDbError(e));
```

- [ ] **Step 3: Analyze + commit**

```bash
flutter analyze --no-fatal-infos
git add lib/
git commit -m "fix(ux): replace raw error-object snackbars with friendlyDbError messages"
```

---

### Task 3: Expand test coverage (168 lines → meaningful suite)

**Files:**
- Modify: `app/test/core_logic_test.dart`
- Create: `app/test/features/rental_request/rental_flow_test.dart`
- Create: `app/test/features/auth/auth_repository_test.dart`
- Create: `app/test/features/generators/generator_repository_test.dart`

**What:** Cover the 3 most critical flows with unit tests. No Flutter widget tests required — pure Dart repository + business logic tests.

- [ ] **Step 1: Add rental flow unit tests**

Create `app/test/features/rental_request/rental_flow_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:andaloes/features/rental_request/domain/entities/rental_request_entity.dart';

void main() {
  group('Rental price calculation', () {
    test('total = days × price_per_day', () {
      const pricePerDay = 500.0;
      const days = 3;
      final total = pricePerDay * days;
      expect(total, 1500.0);
    });

    test('inclusive date range: end=start gives 1 day', () {
      final start = DateTime(2026, 7, 1);
      final end = DateTime(2026, 7, 1);
      final days = end.difference(start).inDays + 1;
      expect(days, 1);
    });

    test('3-day range gives 3 days', () {
      final start = DateTime(2026, 7, 1);
      final end = DateTime(2026, 7, 3);
      final days = end.difference(start).inDays + 1;
      expect(days, 3);
    });

    test('status pending → accepted is valid transition', () {
      const validTransitions = {
        'pending': ['accepted', 'rejected', 'cancelled'],
        'accepted': ['active', 'cancelled'],
        'active': ['done'],
        'rejected': <String>[],
        'cancelled': <String>[],
        'done': <String>[],
      };
      expect(validTransitions['pending'], contains('accepted'));
      expect(validTransitions['done'], isEmpty);
    });

    test('commission calculation: 10% of 1500 = 150', () {
      const total = 1500.0;
      const rate = 0.10;
      final commission = (total * rate).roundToDouble();
      expect(commission, 150.0);
    });
  });
}
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
flutter test test/features/rental_request/rental_flow_test.dart -v
```

Expected: all 5 pass.

- [ ] **Step 3: Run full test suite**

```bash
flutter test --no-pub
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add test/
git commit -m "test: add rental flow + commission unit tests"
```

---

## Phase 1 — Security & Production Hardening

### Task 4: Company documents RLS audit

**What:** The `company_documents` table is unused but exists. Verify its RLS policies are tight (no leaks of owner ID docs).

- [ ] **Step 1: Check table and policies**

Run via Supabase MCP:
```sql
-- Check RLS enabled
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'company_documents';

-- Check existing policies
SELECT policyname, cmd, qual, with_check 
FROM pg_policies WHERE tablename = 'company_documents';
```

Expected: `rowsecurity = true` and policies restrict SELECT to owner + admin only.

- [ ] **Step 2: If RLS is off or policies are missing, apply migration**

Create `supabase/migrations/0041_company_documents_rls.sql`:

```sql
-- Ensure RLS on company_documents
ALTER TABLE company_documents ENABLE ROW LEVEL SECURITY;

-- Owners can read their own company's docs
CREATE POLICY "company_docs_owner_select"
  ON company_documents FOR SELECT
  USING (
    company_id IN (
      SELECT id FROM companies WHERE owner_user_id = auth.uid()
    )
  );

-- Admins can read all
CREATE POLICY "company_docs_admin_all"
  ON company_documents FOR ALL
  USING (is_admin());

-- No INSERT/UPDATE/DELETE for non-admins (docs uploaded via storage, not direct insert)
```

Apply via MCP and verify no errors in Supabase logs.

- [ ] **Step 3: Commit migration**

```bash
git add supabase/migrations/0041_company_documents_rls.sql
git commit -m "fix(security): ensure company_documents RLS is enabled with owner+admin policies"
```

---

### Task 5: Production env validation + debug route guard

**What:** Confirm `kDebugMode` gates `/dev-login` and `/page-hub`. Confirm no service_role key in any client file.

- [ ] **Step 1: Verify dev routes are debug-only**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
grep -n "dev-login\|page-hub\|devLogin\|pageHub" lib/core/routing/app_router.dart | head -10
```

Each dev route must be inside a `if (kDebugMode)` guard or have a redirect that sends non-debug builds away. If missing, add:

```dart
// In app_router.dart, for /dev-login route:
redirect: (context, state) {
  if (!kDebugMode) return '/';
  return null;
},
```

- [ ] **Step 2: Verify no service_role key**

```bash
grep -r "service_role\|eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" lib/ --include="*.dart"
grep -r "service_role" app/ --include="*.yaml" --include="*.json" --include="*.env"
```

Expected: no output. If found → remove immediately and rotate the key in Supabase dashboard.

- [ ] **Step 3: Verify publishable/anon key in env.dart**

```bash
grep -n "publishableKey\|anonKey" lib/core/config/env.dart
```

Must use `publishableKey:` (not deprecated `anonKey:`). Value must be the anon/publishable key, not service_role.

- [ ] **Step 4: Analyze + commit**

```bash
flutter analyze --no-fatal-infos
git add lib/core/routing/app_router.dart lib/core/config/
git commit -m "fix(security): gate dev routes behind kDebugMode, verify no service_role in client"
```

---

### Task 6: Owner KYC — document upload gate (company_documents v1)

**What:** Owners must upload at least one company document before their listing goes live. Wire the unused `company_documents` table: upload form in company onboarding, admin verification UI.

**Files:**
- Create: `lib/features/company/presentation/widgets/company_document_upload.dart`
- Modify: `lib/features/company/presentation/company_onboarding_screen.dart` — add upload step
- Modify: `lib/features/admin/presentation/admin_companies_tab.dart` — show doc count badge

- [ ] **Step 1: Add document upload widget**

Create `lib/features/company/presentation/widgets/company_document_upload.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/config/supabase.dart';
import '../../../../../core/widgets/app_loading_indicator.dart';
import '../../../../../core/widgets/app_snack_bar.dart';
import '../../../../../l10n/app_localizations.dart';

class CompanyDocumentUpload extends ConsumerStatefulWidget {
  const CompanyDocumentUpload({super.key, required this.companyId});
  final String companyId;

  @override
  ConsumerState<CompanyDocumentUpload> createState() =>
      _CompanyDocumentUploadState();
}

class _CompanyDocumentUploadState extends ConsumerState<CompanyDocumentUpload> {
  bool _uploading = false;
  List<Map<String, dynamic>> _docs = [];

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    final rows = await supabase
        .from('company_documents')
        .select('id, doc_type, file_url, created_at')
        .eq('company_id', widget.companyId)
        .order('created_at');
    if (mounted) setState(() => _docs = (rows as List).cast());
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final path = 'company_docs/${widget.companyId}/${file.name}';
      await supabase.storage.from('company-documents').uploadBinary(
            path,
            file.bytes!,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = supabase.storage
          .from('company-documents')
          .getPublicUrl(path);
      await supabase.from('company_documents').insert({
        'company_id': widget.companyId,
        'doc_type': 'national_id',
        'file_url': url,
      });
      await _loadDocs();
      if (mounted) AppSnackBar.success(context, 'Document uploaded');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Upload failed — try again');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Company Documents',
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (_uploading)
              const AppLoadingIndicator(size: 18)
            else
              TextButton.icon(
                onPressed: _pickAndUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Upload'),
              ),
          ],
        ),
        if (_docs.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8),
            child: Text(
              'Upload your national ID or business license to verify ownership.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          )
        else
          ..._docs.map((d) => ListTile(
                dense: true,
                leading: const Icon(Icons.description_rounded),
                title: Text(d['doc_type']?.toString() ?? 'Document'),
                subtitle: Text('Uploaded'),
                trailing: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 18),
              )),
      ],
    );
  }
}
```

- [ ] **Step 2: Add upload step to company onboarding (final step)**

In `lib/features/company/presentation/company_onboarding_screen.dart`, after the company is created (after `.insert()` succeeds and `_companyId` is set), show a document upload step:

```dart
// After company insert succeeds, show document upload:
if (_step == 0 && _companyId != null) {
  setState(() => _step = 1); // step 1 = document upload
}
```

Add a Step 1 page to the screen that shows `CompanyDocumentUpload(companyId: _companyId!)` with a "Submit for Review" button that navigates to `/owner-dashboard`.

- [ ] **Step 3: Analyze**

```bash
flutter analyze --no-fatal-infos
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 4: Commit**

```bash
git add lib/features/company/
git commit -m "feat(company): add document upload step to onboarding (KYC v1)"
```

---

## Phase 2 — Core Journey Polish

### Task 7: Safety acknowledgment at checkout

**What:** Before a customer confirms a rental request, show a one-time (per session) safety acknowledgment: "Generator must be used outdoors. Never operate indoors — CO risk." Customer must tap "I understand" to proceed.

**Files:**
- Create: `lib/features/rental_request/presentation/widgets/safety_ack_dialog.dart`
- Modify: `lib/features/rental_request/presentation/rental_request_screen.dart`

- [ ] **Step 1: Create SafetyAckDialog**

Create `lib/features/rental_request/presentation/widgets/safety_ack_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SafetyAckDialog extends StatelessWidget {
  const SafetyAckDialog({super.key});

  static Future<bool> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('safety_ack_shown') == true) return true;
    if (!context.mounted) return false;
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SafetyAckDialog(),
    );
    if (agreed == true) {
      await prefs.setBool('safety_ack_shown', true);
    }
    return agreed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded,
          color: cs.error, size: 40),
      title: const Text('Safety Notice'),
      content: const Text(
        'Generators must ALWAYS be operated outdoors in well-ventilated areas.\n\n'
        'Never run a generator indoors, in a garage, or near windows — '
        'it produces carbon monoxide (CO) which is odourless and deadly.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('I understand'),
        ),
      ],
    );
  }
}
```

Add Arabic strings to `app_en.arb` and `app_ar.arb`:
```json
// app_en.arb
"safetyNoticeTitle": "Safety Notice",
"safetyNoticeBody": "Generators must ALWAYS be operated outdoors in well-ventilated areas. Never run a generator indoors — it produces CO which is deadly.",
"safetyIUnderstand": "I understand"

// app_ar.arb
"safetyNoticeTitle": "تنبيه السلامة",
"safetyNoticeBody": "يجب تشغيل المولدات دائمًا في الخارج في أماكن جيدة التهوية. لا تشغّل مولدًا في الداخل أبدًا — ينتج أول أكسيد الكربون (CO) الذي يُودي بالحياة.",
"safetyIUnderstand": "فهمت"
```

- [ ] **Step 2: Wire to rental_request_screen.dart confirm button**

In `lib/features/rental_request/presentation/rental_request_screen.dart`, find the `_confirm()` or submit handler. Before calling the repository:

```dart
Future<void> _confirm() async {
  // Safety ack first (shown once per install)
  final acked = await SafetyAckDialog.checkAndShow(context);
  if (!acked) return;
  
  // ... existing confirm logic
}
```

- [ ] **Step 3: Run flutter gen-l10n**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter gen-l10n
```

- [ ] **Step 4: Analyze**

```bash
flutter analyze --no-fatal-infos
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/features/rental_request/ lib/l10n/
git commit -m "feat(rental): add safety acknowledgment dialog at checkout (one-time per install)"
```

---

### Task 8: Owner onboarding polish — validation + better empty state

**What:** Company onboarding screen must show clear validation errors inline, and the owner dashboard empty state (no company yet) must have a clear CTA.

**Files:**
- Modify: `lib/features/company/presentation/company_onboarding_screen.dart`
- Modify: `lib/features/owner_dashboard/presentation/owner_dashboard_screen.dart`

- [ ] **Step 1: Add form validation to onboarding**

In `company_onboarding_screen.dart`, wrap the form in a `Form` widget with a `GlobalKey<FormState>`. Add `validator` to each `TextFormField`:

```dart
final _formKey = GlobalKey<FormState>();

// Company name field:
validator: (v) => (v == null || v.trim().isEmpty)
    ? 'Company name is required'
    : v.trim().length < 3
        ? 'At least 3 characters'
        : null,

// Phone field:
validator: (v) => (v == null || v.trim().isEmpty)
    ? 'Phone number is required'
    : null,
```

Before submitting, call `_formKey.currentState!.validate()`.

- [ ] **Step 2: Owner dashboard — no-company empty state**

In `owner_dashboard_screen.dart`, when `myCompanyProvider` returns null (owner has no company yet):

```dart
// Replace bare Text('No company') or similar with:
AppEmptyState(
  icon: Icons.business_rounded,
  title: 'Set up your company',
  subtitle: 'Create your company profile to start listing generators.',
  action: () => context.go('/company/onboard'),
  actionLabel: 'Create company',
)
```

Import: `import '../../../../core/widgets/app_empty_state.dart';`

- [ ] **Step 3: Analyze + commit**

```bash
flutter analyze --no-fatal-infos
git add lib/features/company/ lib/features/owner_dashboard/
git commit -m "fix(ux): add form validation to company onboarding + better empty state"
```

---

### Task 9: Booking golden path audit — fix edge cases

**What:** Walk the full flow programmatically and fix any identified dead ends.

- [ ] **Step 1: Trace the golden path in code**

Check each step in the rental request flow:

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
# 1. Guest browsing → detail
grep -n "auth\|guest\|anonymous" lib/features/generators/presentation/screens/generator_detail_screen.dart | head -10

# 2. Date picker → conflict check
grep -n "overlapCount\|conflict\|booked" lib/features/rental_request/presentation/rental_request_screen.dart | head -10

# 3. Confirm → payment screen
grep -n "go('/\|push(" lib/features/rental_request/presentation/rental_request_screen.dart | head -10

# 4. Owner sees request → accept → customer sees accepted
grep -n "accepted\|fetchRequests\|ownerRequest" lib/features/owner_dashboard/presentation/widgets/owner_requests_tab.dart | head -10

# 5. Owner marks active → done flow
grep -n "active\|done\|complete\|deliver" lib/features/owner_dashboard/presentation/widgets/request_card.dart | head -10
```

- [ ] **Step 2: Fix any null-safety or missing state issues found**

Common issues to look for:
- `context.mounted` check missing after any `await` before using `context`
- Missing `if (!mounted) return;` after async calls in StatefulWidgets
- Any screen that can receive a null `rentalId` from GoRouter without handling it

Pattern:
```dart
// BEFORE (unsafe)
await repo.doSomething();
ScaffoldMessenger.of(context).showSnackBar(...);

// AFTER (safe)
await repo.doSomething();
if (!context.mounted) return;
ScaffoldMessenger.of(context).showSnackBar(...);
```

- [ ] **Step 3: Analyze + commit**

```bash
flutter analyze --no-fatal-infos
git add lib/
git commit -m "fix(rental): context.mounted safety guards in async rental flow callbacks"
```

---

## Phase 3 — Production Build

### Task 10: Release build validation

**What:** Ensure a release APK compiles clean. Catch any debug-only code paths that break in release.

- [ ] **Step 1: Build release APK**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
flutter build apk --release --no-pub 2>&1 | tail -20
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-release.apk`

If build fails: fix the errors (common: missing `const`, reflection issues, obfuscation of Supabase types).

- [ ] **Step 2: Build debug APK for device test**

```bash
flutter build apk --debug --no-pub
```

- [ ] **Step 3: Verify app size**

```bash
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

Acceptable: < 50MB. If larger, add to `android/app/build.gradle`:
```groovy
buildTypes {
  release {
    shrinkResources true
    minifyEnabled true
  }
}
```

- [ ] **Step 4: Commit any release-mode fixes**

```bash
git add android/ lib/
git commit -m "chore(release): fix release build issues, enable shrinkResources"
```

---

### Task 11: Merge development → main + tag MVP

- [ ] **Step 1: Final analyze on development**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
flutter test --no-pub
```

Both must pass clean.

- [ ] **Step 2: Push development**

```bash
git push origin development
```

- [ ] **Step 3: Create PR development → main**

```bash
gh pr create \
  --base main \
  --head development \
  --title "MVP: clean architecture + Arabic-first + launch readiness" \
  --body "$(cat <<'EOF'
## Summary

- Full clean architecture across all 11 features (domain/data/presentation)
- Zero supabase.* in presentation layer — all queries behind repositories
- Arabic-first + RTL complete (31 screens, real Arabic, proper plural categories)
- 6 shared core widgets (AppSnackBar, AppConfirmDialog, AppLoadingIndicator, AppStatusBadge, AppEmptyState, AppErrorState)
- All screen files under 800 lines (profile 1584→387, detail 1014→67, my_rentals 1160→barrel)
- CachedNetworkImage for all generator photos
- Safety acknowledgment at checkout
- Company document upload (KYC v1)
- Production security: dev routes gated, no service_role in client, company_documents RLS verified
- Release APK builds clean

## Test plan
- [ ] Browse generators as guest
- [ ] Sign up with email, confirm email in inbox
- [ ] Request a generator (pick dates, safety ack, confirm)
- [ ] As owner: accept request, mark delivered, mark completed
- [ ] As customer: rate the rental
- [ ] As admin: approve a company, approve a listing, resolve a report
- [ ] Switch language to English in Profile → Language
- [ ] Dark mode toggle works
- [ ] Release APK installs on Android device
EOF
)"
```

- [ ] **Step 4: After CI passes → merge and tag**

```bash
gh pr merge --squash
git checkout main
git pull
git tag -a v1.0.0-mvp -m "AnDaLoeS MVP — Arabic-first generator rental marketplace"
git push origin v1.0.0-mvp
```

---

## Phase 4 — Post-MVP (blocked on owner decisions)

These are NOT in scope for MVP — they require external setup:

| Item | Blocker | Effort |
|------|---------|--------|
| FCM push notifications | FCM project + APNs cert | 1 day |
| Phone OTP | SMS provider (Twilio/Vonage) | 0.5 day |
| Paymob digital payments | Merchant account + CBE review | 3 days |
| Commission auto-enforcement | Owner revenue model decision (A/B/C/D) | 2 days |
| Web build + SEO | Web SDK passkeys fix | 2 days |
| Owner KYC doc review in admin | Admin workflow decision | 1 day |
| iOS App Store release | Apple developer account, provisioning | 1 day |
| Owner blocklist | Product decision | 0.5 day |

**Manual step required NOW (owner action):**
- Log into Supabase dashboard → Authentication → Settings → enable "Confirm email"
- Creates `company-documents` storage bucket with private access (or the document upload in Task 6 will fail)

---

## Execution order

Tasks 1–3 can run in parallel (no file conflicts).  
Tasks 4–5 can run in parallel with 1–3.  
Tasks 6–9 run after 1–5 complete.  
Tasks 10–11 run last (need everything else done).
