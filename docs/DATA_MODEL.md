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

### `generators`
A rentable unit listed by an owner.

| column | type | notes |
|---|---|---|
| id | uuid (PK) | |
| owner_id | uuid (FK → profiles.id) | |
| title | text | e.g. "Cummins 100 KVA" |
| capacity_kva | numeric | generator capacity |
| description | text | |
| price_per_day | numeric | in EGP |
| city | text | |
| location | geography(point) | optional, for map/distance |
| photos | text[] | Supabase Storage URLs |
| status | enum (`available`, `unavailable`) | |
| created_at | timestamptz | |

### `rental_requests`  ← the heart of the app

| column | type | notes |
|---|---|---|
| id | uuid (PK) | |
| customer_id | uuid (FK → profiles.id) | |
| generator_id | uuid (FK → generators.id) | |
| owner_id | uuid (FK → profiles.id) | denormalized for quick owner queries |
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
profiles 1───* generators
profiles 1───* rental_requests        (as customer)
generators 1──* rental_requests
rental_requests 1──1 commissions
rental_requests 1──* payments
```

---

## Row Level Security (RLS) — security from day one

Supabase enforces access at the database. Core policies:

- A user can **read** their own `profile` and update it.
- `generators`: anyone authenticated can **read** `available` generators; only
  the **owner** can insert/update/delete their own.
- `rental_requests`: a customer can **create** and **read their own**; the
  **owner** of the generator can read and update status (accept/reject) on
  requests for their generators.
- `payments` / `commissions`: read restricted to the request's customer/owner;
  writes happen via server-side functions (service role), not the client.

> Rule of thumb: anything involving money (`payments`, `commissions`) is
> written by **Edge Functions** using the service role — never directly from
> the app — so clients can't fabricate financial records.

---

## Status lifecycle (rental_requests)

```
pending ──accept──> accepted ──start──> active ──finish──> completed
   │                                                          │
   └──reject──> rejected                          (create commission row)
   │
   └──cancel──> cancelled   (customer cancels before acceptance)
```
