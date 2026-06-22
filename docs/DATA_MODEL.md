# Data Model

Designed for **Supabase (Postgres)**. The commission marketplace is baked in
from day one so you can earn on every completed rental without changing the
schema later.

> Names use `snake_case` (Postgres convention). All tables have `id uuid`
> primary keys and `created_at` / `updated_at` timestamps (omitted below for
> brevity except where relevant).

---

## Core tables

### `profiles`
Extends Supabase `auth.users` (phone-based). Every app user has one profile.

| column | type | notes |
|---|---|---|
| id | uuid (PK, = auth.users.id) | |
| full_name | text | |
| phone | text | from auth, Egyptian format |
| role | enum (`customer`, `owner`, `admin`) | a user can be both customer & owner |
| city | text | for matching by location |
| created_at | timestamptz | |

### `companies`  ← an owner business (your dad's fleet, or any company that joins)
A company/owner account that lists generators. **Must be verified and approved
by the platform before its generators become visible to customers.**

| column | type | notes |
|---|---|---|
| id | uuid (PK) | |
| owner_user_id | uuid (FK → profiles.id) | the user who manages this company |
| name | text | company / business name |
| contact_phone | text | |
| city | text | |
| verification_status | enum (`pending`, `under_review`, `approved`, `rejected`) | starts `pending` |
| rejection_reason | text | filled when `rejected`, shown to the owner |
| reviewed_by | uuid (FK → profiles.id) | admin who approved/rejected |
| reviewed_at | timestamptz | |
| created_at | timestamptz | |

### `company_documents`  ← verification evidence (Egypt)
Files an owner uploads to prove they're a real business, reviewed by admin.

| column | type | notes |
|---|---|---|
| id | uuid (PK) | |
| company_id | uuid (FK → companies.id) | |
| doc_type | enum (`commercial_register`, `tax_card`, `national_id`, `other`) | |
| file_url | text | Supabase Storage (private bucket) |
| created_at | timestamptz | |

> Typical Egyptian business documents: **commercial registration** (السجل
> التجاري), **tax card** (البطاقة الضريبية), and the owner's **national ID**.
> Adjust the `doc_type` list to whatever you decide to require.

### `generators`
A rentable unit listed by a company.

| column | type | notes |
|---|---|---|
| id | uuid (PK) | |
| company_id | uuid (FK → companies.id) | owning company |
| title | text | e.g. "Cummins 100 KVA" |
| capacity_kva | numeric | generator capacity |
| description | text | |
| price_per_day | numeric | in EGP |
| city | text | |
| location | geography(point) | optional, for map/distance |
| photos | text[] | Supabase Storage URLs |
| status | enum (`available`, `unavailable`) | owner's own on/off switch |
| created_at | timestamptz | |

> **Visibility rule:** a generator is shown to customers only when **both** its
> `status = available` **and** its company's `verification_status = approved`.
> So a pending company can prepare its listings, but nothing goes live until you
> approve them.

### `rental_requests`  ← the heart of the app

| column | type | notes |
|---|---|---|
| id | uuid (PK) | |
| customer_id | uuid (FK → profiles.id) | |
| generator_id | uuid (FK → generators.id) | |
| company_id | uuid (FK → companies.id) | denormalized for quick owner-side queries |
| start_date | date | |
| end_date | date | |
| total_days | int | computed |
| price_total | numeric | total_days × price_per_day |
| status | enum | `pending` → `accepted` → `active` → `completed` / `rejected` / `cancelled` |
| note | text | optional customer note |
| created_at | timestamptz | |

### `payments` (phase 2)

| column | type | notes |
|---|---|---|
| id | uuid (PK) | |
| rental_request_id | uuid (FK) | |
| amount | numeric | EGP |
| gateway | enum (`paymob`, `fawry`, `cash`) | |
| gateway_ref | text | transaction id from provider |
| status | enum (`pending`, `paid`, `failed`, `refunded`) | |
| created_at | timestamptz | |

### `commissions`  ← how the platform earns

| column | type | notes |
|---|---|---|
| id | uuid (PK) | |
| rental_request_id | uuid (FK) | |
| rental_amount | numeric | the rental's price_total |
| commission_rate | numeric | e.g. 0.10 = 10% |
| commission_amount | numeric | rental_amount × commission_rate |
| status | enum (`accrued`, `settled`) | |
| created_at | timestamptz | |

A `commission` row is created when a `rental_request` reaches `completed`.

---

## Relationships

```
profiles 1───* companies              (owner_user_id: a user manages a company)
companies 1──* company_documents
companies 1──* generators
profiles 1───* rental_requests        (as customer)
companies 1──* rental_requests        (owner side)
generators 1──* rental_requests
rental_requests 1──1 commissions
rental_requests 1──* payments
```

---

## Row Level Security (RLS) — security from day one

Supabase enforces access at the database. Core policies:

- A user can **read** their own `profile` and update it.
- `companies`: a user can **create** and manage **their own** company; **only an
  admin** can change `verification_status` (approve/reject). Customers can read
  only **approved** companies.
- `company_documents`: readable only by the owning company's user and admins;
  stored in a **private** Storage bucket.
- `generators`: anyone authenticated can **read** generators that are
  `available` **and** whose company is `approved`; only the owning company can
  insert/update/delete its own.
- `rental_requests`: a customer can **create** and **read their own**; the
  **owning company's** user can read and update status (accept/reject) on
  requests for their generators.
- `payments` / `commissions`: read restricted to the request's customer/company;
  writes happen via server-side functions (service role), not the client.

> Rule of thumb: anything involving money (`payments`, `commissions`) or trust
> (`verification_status`) is written by **Edge Functions** using the service
> role — never directly from the app — so clients can't fabricate financial
> records or self-approve their own company.

---

## Status lifecycle (rental_requests)

```
pending ──accept──> accepted ──start──> active ──finish──> completed
   │                                                          │
   └──reject──> rejected                          (create commission row)
   │
   └──cancel──> cancelled   (customer cancels before acceptance)
```

---

## Company verification lifecycle (onboarding new owners)

```
company created (pending)
        │  owner uploads documents
        ▼
   under_review  ──admin approves──> approved   (generators can go live)
        │
        └────────admin rejects────> rejected    (rejection_reason shown;
                                                  owner can fix & resubmit)
```

Only an **admin** (you) can move a company to `approved`. Generators stay
hidden from customers until that happens — so any company can sign up and
prepare listings, but you control who actually goes live.
