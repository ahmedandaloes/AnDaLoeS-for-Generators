# AnDaLoeS — Users & Role-Based Access Control (RBAC)

> **Rule:** Every new feature must be designed against this matrix before coding.
> If a feature adds a screen, button, action, or DB write — ask:
> "Which roles can see/do this?" and enforce it in BOTH Flutter routing AND Supabase RLS.

---

## 1. Roles

The app has four user states stored in `profiles.role` (Postgres enum `user_role`):

| Role | Value | Who |
|------|-------|-----|
| **Guest** | *(anonymous auth user)* | Unregistered visitor — auto-created anon session |
| **Customer** | `customer` | Registered renter who books generators |
| **Owner** | `owner` | Generator owner who lists and manages inventory |
| **Admin** | `admin` | Platform operator — moderation + support |

> `guest` is not a DB value — it maps to `profiles.role = null` or an anonymous Supabase auth user (`user.isAnonymous == true`). A guest gets a `customer` profile the moment they sign up.

---

## 2. Feature Access Matrix

### 2.1 Browse & Discovery

| Feature | Guest | Customer | Owner | Admin |
|---------|-------|----------|-------|-------|
| Browse home, search, filter | ✅ | ✅ | ✅ | ✅ |
| View generator detail | ✅ | ✅ | ✅ | ✅ |
| View availability calendar | ✅ | ✅ | ✅ | ✅ |
| View company profile | ✅ | ✅ | ✅ | ✅ |
| Map view | ✅ | ✅ | ✅ | ✅ |
| Save favorites | ❌ (prompt signup) | ✅ | ✅ | ✅ |
| Save searches | ❌ (prompt signup) | ✅ | ✅ | ✅ |

### 2.2 Rental & Booking

| Feature | Guest | Customer | Owner | Admin |
|---------|-------|----------|-------|-------|
| Start rental request flow | ✅ (date picker) | ✅ | ❌ | ❌ |
| Submit rental request | ❌ (prompt signup) | ✅ | ❌ | ❌ |
| Cancel own pending request | ❌ | ✅ | ❌ | ✅ |
| View My Rentals | ❌ | ✅ | ❌ | ✅ (all) |
| View rental offer (accepted) | ❌ | ✅ (own) | ✅ (own) | ✅ |
| View invoice (completed) | ❌ | ✅ (own) | ✅ (own) | ✅ |
| Confirm receipt (→ active) | ❌ | ✅ (own) | ❌ | ❌ |
| Rate after completion | ❌ | ✅ (own) | ✅ (own) | ❌ |

### 2.3 Owner Dashboard

| Feature | Guest | Customer | Owner | Admin |
|---------|-------|----------|-------|-------|
| View Owner Dashboard | ❌ | ❌ | ✅ | ✅ |
| Add / Edit / Clone generator | ❌ | ❌ | ✅ (own) | ✅ |
| Accept / Reject rental request | ❌ | ❌ | ✅ (own) | ✅ |
| Mark out for delivery | ❌ | ❌ | ✅ (own) | ✅ |
| Confirm handover / complete | ❌ | ❌ | ✅ (own) | ✅ |
| View own earnings | ❌ | ❌ | ✅ (own) | ✅ |
| View owner company profile | ❌ | ❌ | ✅ (own) | ✅ |

### 2.4 Admin Panel

| Feature | Guest | Customer | Owner | Admin |
|---------|-------|----------|-------|-------|
| Admin screen (any tab) | ❌ | ❌ | ❌ | ✅ |
| Approve / reject company | ❌ | ❌ | ❌ | ✅ |
| Approve / reject / suspend generator | ❌ | ❌ | ❌ | ✅ |
| Resolve disputes / reports | ❌ | ❌ | ❌ | ✅ |
| **Customer support view** (rental history, disputes by customer) | ❌ | ❌ | ❌ | ✅ |
| **Owner support view** (listings, company status, ops overdue) | ❌ | ❌ | ❌ | ✅ |
| Platform stats, revenue | ❌ | ❌ | ❌ | ✅ |
| Edit commission config | ❌ | ❌ | ❌ | ✅ |
| Edit tax config | ❌ | ❌ | ❌ | ✅ |

### 2.5 Chat

| Feature | Guest | Customer | Owner | Admin |
|---------|-------|----------|-------|-------|
| Open chat thread | ❌ | ✅ (own rental) | ✅ (own rental) | ✅ (any) |
| Send message | ❌ | ✅ (own rental) | ✅ (own rental) | ❌ (read-only) |

### 2.6 Reports

| Feature | Guest | Customer | Owner | Admin |
|---------|-------|----------|-------|-------|
| File a report | ❌ | ✅ | ✅ | ❌ |
| View all reports | ❌ | ❌ | ❌ | ✅ |
| Resolve / dismiss report | ❌ | ❌ | ❌ | ✅ |

---

## 3. Enforcement Layers

### 3.1 Flutter routing (GoRouter guard — `app_router.dart`)

```dart
// Protected route groups:
// /owner/* → role must be 'owner' or 'admin'
// /admin    → role must be 'admin'
// /profile, /my-rentals, /notifications, etc. → must be logged-in (non-anonymous)
```

The `_roleCache` ValueNotifier refreshes on every `onAuthStateChange`. The redirect function checks `role` and `user.isAnonymous` before allowing navigation.

### 3.2 Supabase RLS (database layer)

Helper functions (defined in migration 0002):

```sql
-- is the current user an admin?
create function public.is_admin() returns boolean as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$ language sql security definer stable;

-- does the current user own the company?
create function public.owns_company(p_company_id uuid) returns boolean as $$
  select exists (select 1 from companies where id = p_company_id and owner_user_id = auth.uid());
$$ language sql security definer stable;
```

RLS policy pattern per table:

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| `profiles` | own row OR admin | own row | own row | — |
| `companies` | owns OR admin | owns | owns OR admin | owns |
| `generators` | public | owns company | owns company OR admin | owns company |
| `rental_requests` | customer OR owns company OR admin | customer | customer OR owns company OR admin | — |
| `ratings` | public | rater (own rental) | — | — |
| `notifications` | own | — | own | own |
| `commissions` | owns company OR admin | — | admin | — |
| `reports` | reporter OR admin | any auth user | admin | — |
| `rental_timeline_events` | customer OR owner of company OR admin | owner of company | — | — |
| `rental_handovers` | customer OR owner OR admin | owner | — | — |
| `saved_searches` | own | own | own | own |

---

## 4. Adding a New Feature — Checklist

Before building any new feature:

- [ ] **Identify actors**: which roles can trigger / see this?
- [ ] **Route guard**: add GoRouter redirect rule if new protected route
- [ ] **UI visibility**: hide/disable buttons & tabs by `role` at widget level
- [ ] **RLS policy**: write the policy in a migration before writing app code
- [ ] **Test all roles**: verify guest, customer, owner, admin each see the right thing
- [ ] **ARB strings**: localize ALL role-specific labels in en + ar

---

## 5. Admin Panel — Planned Split (pending implementation)

The current flat 7-tab admin screen mixes customer support and owner support concerns. Planned structure:

### Customer Support section
- Rentals in dispute / under review
- All customer rental history (searchable by phone/name)
- Report resolution (customer-filed reports)
- User management (ban, role change)

### Owner Support section
- Company approvals (pending → approved/rejected)
- Generator listing approvals
- Overdue / stale rentals ops view
- Owner earnings disputes

### Platform section (shared)
- Stats dashboard
- Revenue & commission config
- Tax config

---

## 6. Role Escalation Flow

```
Guest (anon)
   │  signs up (email+password)
   ▼
Customer
   │  creates a company (onboarding flow)
   ▼
Owner (profile.role updated to 'owner' by DB trigger on company insert)

Customer / Owner
   │  manually set by admin in profiles table
   ▼
Admin
```

> The role change from `customer` → `owner` happens automatically via a Supabase DB trigger when a company is first inserted by that user (see migration 0003 or equivalent). Admins are set manually — there is no self-serve admin signup path.
