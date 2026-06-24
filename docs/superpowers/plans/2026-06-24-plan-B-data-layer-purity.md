# Plan B: Data Layer Purity — Supabase Out of Presentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all direct `supabase.` calls from every file under `presentation/` — all queries must go through the feature's `data/repositories/` class.

**Architecture:** Each violation is extracted to its feature's existing repository, exposed as a new method, then the provider/widget calls `ref.read(xRepositoryProvider).newMethod()` instead of `supabase.from(...)` directly. Auth is special: `supabase.auth.*` is allowed inside `AuthRepository` only.

**Tech Stack:** Flutter 3.44, Riverpod v2, Supabase Flutter v2, Dart

## Global Constraints

- Working directory: `/Users/andaloes/AnDaLoeS-for-Generators/app`
- Branch: `development`
- `flutter analyze --no-fatal-infos` → 0 errors after EVERY task
- Keep all existing public provider variable names identical — callers must not change
- `withValues(alpha:)` not `.withOpacity()`
- `Set.from()` not spread cascade
- Never commit generated l10n files
- Commit format: `refactor(<feature>): move supabase queries to data layer`

---

### Task 1: owner_dashboard — move 5 inline queries to OwnerRepository

**Files to modify:**
- `lib/features/owner_dashboard/data/repositories/owner_repository.dart` — add 3 new methods
- `lib/features/owner_dashboard/presentation/providers/owner_providers.dart` — remove direct supabase calls

**Current violations in `owner_providers.dart`:**
1. `commissionConfigProvider` — queries `commission_config` table directly
2. `myCompanyProvider` — queries `companies` table directly  
3. `ownerHistoryProvider` — queries `rental_requests` table directly

- [ ] **Step 1: Add methods to OwnerRepository**

Open `lib/features/owner_dashboard/data/repositories/owner_repository.dart` and add after the last existing method:

```dart
  Future<List<Map<String, dynamic>>> fetchCommissionConfig() async {
    final data = await supabase
        .from('commission_config')
        .select('type, value, company_id')
        .eq('active', true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> fetchMyCompanyByUid(String uid) async {
    return await supabase
        .from('companies')
        .select()
        .eq('owner_user_id', uid)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchHistory(String companyId) async {
    return await supabase
        .from('rental_requests')
        .select('*, generators(title, capacity_kva), profiles(full_name, phone)')
        .eq('company_id', companyId)
        .inFilter('status', ['done', 'cancelled'])
        .order('created_at', ascending: false)
        .limit(100);
  }
```

- [ ] **Step 2: Update owner_providers.dart — remove supabase import, use repository**

Replace the entire content of `lib/features/owner_dashboard/presentation/providers/owner_providers.dart` with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/commission.dart';
import '../../data/repositories/owner_repository.dart';

export '../../data/repositories/owner_repository.dart'
    show ownerRepositoryProvider;

final commissionConfigProvider =
    FutureProvider.autoDispose.family<CommissionRule?, String>(
        (ref, companyId) async {
  final list = await ref.read(ownerRepositoryProvider).fetchCommissionConfig();
  if (list.isEmpty) return null;
  Map<String, dynamic>? pick;
  for (final r in list) {
    if (r['company_id']?.toString() == companyId) {
      pick = r;
      break;
    }
  }
  pick ??= list.firstWhere((r) => r['company_id'] == null,
      orElse: () => list.first);
  return (
    type: pick['type']?.toString() ?? 'percentage',
    value: (pick['value'] as num?)?.toDouble() ?? 0,
  );
});

final myCompanyProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final repo = ref.read(ownerRepositoryProvider);
  // uid comes from the repository's supabase.auth, kept internal to data layer
  final uid = repo.currentUserId;
  if (uid == null) return null;
  return repo.fetchMyCompanyByUid(uid);
});

final ownerRequestsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  return ref.read(ownerRepositoryProvider).fetchRequests(
    companyId,
    statuses: ['pending', 'accepted', 'active'],
  );
});

final ownerHistoryProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  return ref.read(ownerRepositoryProvider).fetchHistory(companyId);
});
```

- [ ] **Step 3: Add `currentUserId` getter to OwnerRepository**

In `lib/features/owner_dashboard/data/repositories/owner_repository.dart`, add this getter after the class opening brace (before the first method):

```dart
  String? get currentUserId => supabase.auth.currentUser?.id;
```

- [ ] **Step 4: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner_dashboard/
git commit -m "refactor(owner_dashboard): move commission/company/history queries to data layer"
```

---

### Task 2: owner_dashboard widgets — remove supabase from 5 widget files

**Files to modify:**
- `lib/features/owner_dashboard/presentation/widgets/owner_generators_tab.dart`
- `lib/features/owner_dashboard/presentation/widgets/owner_requests_tab.dart`
- `lib/features/owner_dashboard/presentation/widgets/request_card.dart`
- `lib/features/owner_dashboard/presentation/widgets/thin_supply_nudge.dart`
- `lib/features/owner_dashboard/presentation/owner_dashboard_screen.dart`
- `lib/features/owner_dashboard/presentation/owner_earnings_screen.dart`
- `lib/features/owner_dashboard/presentation/add_generator_screen.dart`
- `lib/features/owner_dashboard/presentation/edit_generator_screen.dart`

- [ ] **Step 1: Audit each file's supabase usages**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
for f in \
  lib/features/owner_dashboard/presentation/widgets/owner_generators_tab.dart \
  lib/features/owner_dashboard/presentation/widgets/owner_requests_tab.dart \
  lib/features/owner_dashboard/presentation/widgets/request_card.dart \
  lib/features/owner_dashboard/presentation/widgets/thin_supply_nudge.dart \
  lib/features/owner_dashboard/presentation/owner_dashboard_screen.dart \
  lib/features/owner_dashboard/presentation/owner_earnings_screen.dart \
  lib/features/owner_dashboard/presentation/add_generator_screen.dart \
  lib/features/owner_dashboard/presentation/edit_generator_screen.dart; do
  echo "=== $f ===" && grep -n "supabase\." "$f"
done
```

For each `supabase.from(...)` or `supabase.auth.*` call found:
- If it's a DB query: extract to `OwnerRepository` as a new method, call `ref.read(ownerRepositoryProvider).newMethod()` from provider.
- If it's `supabase.auth.currentUser`: replace with `ref.read(ownerRepositoryProvider).currentUserId`.
- If in a widget directly (no provider): move the call to a FutureProvider in `owner_providers.dart`.

- [ ] **Step 2: Remove supabase import lines from each modified widget**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
grep -n "import.*core/config/supabase\|import.*supabase_flutter" \
  lib/features/owner_dashboard/presentation/widgets/owner_generators_tab.dart \
  lib/features/owner_dashboard/presentation/widgets/owner_requests_tab.dart \
  lib/features/owner_dashboard/presentation/widgets/request_card.dart
```

Delete each such import line from the file (use Edit tool, replace the import line with empty string).

- [ ] **Step 3: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/owner_dashboard/
git commit -m "refactor(owner_dashboard): remove direct supabase from all widget and screen files"
```

---

### Task 3: rental_request — move inline queries to RentalRepository

**Files to modify:**
- `lib/features/rental_request/data/repositories/rental_repository.dart` — add methods
- `lib/features/rental_request/presentation/providers/rental_providers.dart`
- `lib/features/rental_request/presentation/my_rentals_screen.dart`
- `lib/features/rental_request/presentation/rental_receipt_screen.dart`
- `lib/features/rental_request/presentation/rental_offer_screen.dart`
- `lib/features/rental_request/presentation/invoice_screen.dart`

- [ ] **Step 1: Audit rental presentation supabase usages**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
for f in \
  lib/features/rental_request/presentation/providers/rental_providers.dart \
  lib/features/rental_request/presentation/my_rentals_screen.dart \
  lib/features/rental_request/presentation/rental_receipt_screen.dart \
  lib/features/rental_request/presentation/rental_offer_screen.dart \
  lib/features/rental_request/presentation/invoice_screen.dart; do
  echo "=== $f ===" && grep -n "supabase\." "$f"
done
```

- [ ] **Step 2: For each query found, add a method to RentalRepository**

Open `lib/features/rental_request/data/repositories/rental_repository.dart`. For every `supabase.from(...)` found in step 1, add a corresponding method. Pattern:

```dart
  // Example — adapt table/columns to what the audit shows
  Future<Map<String, dynamic>?> fetchReceiptById(String rentalId) async {
    return await supabase
        .from('rental_requests')
        .select('*, generators(*), profiles!customer_id(*), companies(*)')
        .eq('id', rentalId)
        .single();
  }
```

- [ ] **Step 3: Update each presentation file to call repository**

For each file from Step 1: remove the `supabase.` call, import the repository or provider, call `ref.read(rentalRepositoryProvider).methodName(...)` instead.

Remove `import '../../../../core/config/supabase.dart';` from each file after the replacement.

- [ ] **Step 4: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/rental_request/
git commit -m "refactor(rental_request): move all inline supabase queries to data layer"
```

---

### Task 4: auth — wrap supabase.auth calls in AuthRepository

**Files to modify:**
- `lib/features/auth/presentation/login_screen.dart`
- `lib/features/auth/presentation/email_login_screen.dart`
- `lib/features/auth/presentation/email_auth_screen.dart`
- `lib/features/auth/presentation/providers/auth_providers.dart`

AuthRepository already has `signInWithEmailPassword`, `signOut`, `signUpWithEmailPassword`, `upgradeAnonymous`. The presentation files likely call `supabase.auth.signIn*` directly instead.

- [ ] **Step 1: Audit auth presentation supabase usages**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
for f in \
  lib/features/auth/presentation/login_screen.dart \
  lib/features/auth/presentation/email_login_screen.dart \
  lib/features/auth/presentation/email_auth_screen.dart \
  lib/features/auth/presentation/providers/auth_providers.dart; do
  echo "=== $f ===" && grep -n "supabase\." "$f"
done
```

- [ ] **Step 2: Replace each direct auth call with AuthRepository method**

Pattern — replace:
```dart
// BEFORE
await supabase.auth.signInWithPassword(email: email, password: password);
// AFTER
await ref.read(authRepositoryProvider).signInWithEmailPassword(email, password);
```

If `authRepositoryProvider` isn't already imported, add:
```dart
import '../../data/repositories/auth_repository.dart';
```

- [ ] **Step 3: Remove supabase imports from auth presentation files**

```bash
grep -n "import.*core/config/supabase\|import.*supabase_flutter" \
  lib/features/auth/presentation/login_screen.dart \
  lib/features/auth/presentation/email_login_screen.dart \
  lib/features/auth/presentation/email_auth_screen.dart \
  lib/features/auth/presentation/providers/auth_providers.dart
```

Delete each found import line.

- [ ] **Step 4: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/
git commit -m "refactor(auth): route all supabase.auth calls through AuthRepository"
```

---

### Task 5: chat — remove supabase from chat_screen.dart

**Files to modify:**
- `lib/features/chat/data/repositories/chat_repository.dart` (if exists) OR create
- `lib/features/chat/presentation/chat_screen.dart`

- [ ] **Step 1: Check chat repo**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app
ls lib/features/chat/data/repositories/ 2>/dev/null || echo "none"
grep -n "supabase\." lib/features/chat/presentation/chat_screen.dart | head -20
```

- [ ] **Step 2: Create ChatRepository if not present, or add methods**

If no chat repository exists, create `lib/features/chat/data/repositories/chat_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';

final chatRepositoryProvider = Provider((_) => ChatRepository());

class ChatRepository {
  Future<List<Map<String, dynamic>>> fetchMessages(String rentalId) async {
    return await supabase
        .from('messages')
        .select()
        .eq('rental_id', rentalId)
        .order('created_at');
  }

  Future<void> sendMessage({
    required String rentalId,
    required String senderId,
    required String content,
  }) async {
    await supabase.from('messages').insert({
      'rental_id': rentalId,
      'sender_id': senderId,
      'content': content,
    });
  }

  Stream<List<Map<String, dynamic>>> messagesStream(String rentalId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('rental_id', rentalId)
        .order('created_at')
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }
}
```

If a chat repository already exists, add any missing methods following the same pattern.

- [ ] **Step 3: Update chat_screen.dart to use ChatRepository**

Remove `import '../../../../core/config/supabase.dart';` from `chat_screen.dart`.
Replace each `supabase.from('messages')` call with the corresponding `ref.read(chatRepositoryProvider).methodName(...)` call.

- [ ] **Step 4: Analyze**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators/app && flutter analyze --no-fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 5: Final verify — zero supabase in presentation**

```bash
grep -r "import.*core/config/supabase\|import.*supabase_flutter" \
  lib/features/*/presentation/ --include="*.dart"
```

Expected: no output (zero violations).

- [ ] **Step 6: Commit and push**

```bash
git add lib/features/chat/
git commit -m "refactor(chat): move supabase queries to ChatRepository"
git push origin development
```
