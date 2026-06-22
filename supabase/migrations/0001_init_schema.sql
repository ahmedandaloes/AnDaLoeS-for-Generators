-- AnDaLoeS for Generators — initial schema
-- Source of truth: docs/DATA_MODEL.md
-- Target: Supabase (PostgreSQL). Apply via Supabase SQL editor or CLI.
--
-- Notes:
--   * 1 rental day = 8 operating hours (pricing is day/week/month).
--   * Payments are CASH on delivery at launch; gateway enum already supports
--     paymob/fawry for the later online-payment phase.
--   * Commission starts as a configurable FIXED amount per completed rental.

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists "uuid-ossp";
-- PostGIS for generator location/distance (optional but listed in the model).
create extension if not exists postgis;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type user_role            as enum ('customer', 'owner', 'admin');
create type verification_status  as enum ('pending', 'under_review', 'approved', 'rejected');
create type company_doc_type     as enum ('commercial_register', 'tax_card', 'national_id', 'other');
create type generator_status     as enum ('available', 'unavailable');
create type rate_basis           as enum ('day', 'week', 'month');
create type payment_method       as enum ('cash', 'paymob', 'fawry');
create type payment_status       as enum ('pending', 'paid', 'failed', 'refunded');
create type rental_status        as enum ('pending', 'accepted', 'active', 'completed', 'rejected', 'cancelled');
create type commission_type      as enum ('fixed', 'percentage');
create type commission_status    as enum ('accrued', 'settled');

-- ---------------------------------------------------------------------------
-- profiles  (extends auth.users; phone-based auth)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text,
  phone       text,
  role        user_role not null default 'customer',
  city        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- companies  (an owner business; must be approved before its generators show)
-- ---------------------------------------------------------------------------
create table public.companies (
  id                  uuid primary key default uuid_generate_v4(),
  owner_user_id       uuid not null references public.profiles (id) on delete cascade,
  name                text not null,
  contact_phone       text,
  city                text,
  governorate         text,
  verification_status verification_status not null default 'pending',
  rejection_reason    text,
  reviewed_by         uuid references public.profiles (id),
  reviewed_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index companies_owner_idx  on public.companies (owner_user_id);
create index companies_status_idx on public.companies (verification_status);

-- ---------------------------------------------------------------------------
-- company_documents  (verification evidence; stored in a private bucket)
-- ---------------------------------------------------------------------------
create table public.company_documents (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid not null references public.companies (id) on delete cascade,
  doc_type    company_doc_type not null,
  file_url    text not null,
  created_at  timestamptz not null default now()
);
create index company_documents_company_idx on public.company_documents (company_id);

-- ---------------------------------------------------------------------------
-- generators  (rentable units; visible only when available AND company approved)
-- ---------------------------------------------------------------------------
create table public.generators (
  id              uuid primary key default uuid_generate_v4(),
  company_id      uuid not null references public.companies (id) on delete cascade,
  title           text not null,
  capacity_kva    numeric not null,
  description     text,
  price_per_day   numeric not null,             -- 1 day = 8 operating hours
  price_per_week  numeric,
  price_per_month numeric,
  city            text,
  governorate     text,
  location        geography(point, 4326),
  photos          text[] not null default '{}',
  status          generator_status not null default 'available',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index generators_company_idx on public.generators (company_id);
create index generators_gov_idx     on public.generators (governorate);

-- ---------------------------------------------------------------------------
-- rental_requests  (the heart of the app)
-- ---------------------------------------------------------------------------
create table public.rental_requests (
  id              uuid primary key default uuid_generate_v4(),
  customer_id     uuid not null references public.profiles (id) on delete cascade,
  generator_id    uuid not null references public.generators (id) on delete restrict,
  company_id      uuid not null references public.companies (id) on delete restrict,
  start_date      date not null,
  end_date        date not null,
  rate_basis      rate_basis not null,
  total_days      int not null,                 -- 1 day = 8 operating hours
  price_total     numeric not null,
  payment_method  payment_method not null default 'cash',
  status          rental_status not null default 'pending',
  note            text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index rental_requests_customer_idx on public.rental_requests (customer_id);
create index rental_requests_company_idx  on public.rental_requests (company_id);
create index rental_requests_status_idx   on public.rental_requests (status);

-- ---------------------------------------------------------------------------
-- payments  (cash on delivery at launch)
-- ---------------------------------------------------------------------------
create table public.payments (
  id                 uuid primary key default uuid_generate_v4(),
  rental_request_id  uuid not null references public.rental_requests (id) on delete cascade,
  amount             numeric not null,
  gateway            payment_method not null default 'cash',
  gateway_ref        text,
  status             payment_status not null default 'pending',
  created_at         timestamptz not null default now()
);
create index payments_request_idx on public.payments (rental_request_id);

-- ---------------------------------------------------------------------------
-- commission_config  (one active rule; fixed amount to start)
-- ---------------------------------------------------------------------------
create table public.commission_config (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid references public.companies (id) on delete cascade, -- null = platform default
  type        commission_type not null default 'fixed',
  value       numeric not null,                 -- EGP if fixed; rate (0.10) if percentage
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- commissions  (one row per completed rental; rule snapshotted)
-- ---------------------------------------------------------------------------
create table public.commissions (
  id                 uuid primary key default uuid_generate_v4(),
  rental_request_id  uuid not null unique references public.rental_requests (id) on delete cascade,
  rental_amount      numeric not null,
  type               commission_type not null,
  value              numeric not null,
  commission_amount  numeric not null,
  status             commission_status not null default 'accrued',
  created_at         timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated      before update on public.profiles      for each row execute function public.set_updated_at();
create trigger trg_companies_updated     before update on public.companies     for each row execute function public.set_updated_at();
create trigger trg_generators_updated    before update on public.generators    for each row execute function public.set_updated_at();
create trigger trg_rental_req_updated    before update on public.rental_requests for each row execute function public.set_updated_at();
