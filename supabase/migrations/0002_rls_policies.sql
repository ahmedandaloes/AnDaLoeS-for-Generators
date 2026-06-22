-- AnDaLoeS for Generators — Row Level Security
-- Source of truth: docs/DATA_MODEL.md  (RLS section)
--
-- Principle: clients can only touch their own data. Anything involving money
-- (payments, commissions) or trust (company verification_status) is written by
-- Edge Functions using the service role, which BYPASSES RLS — so there are no
-- client INSERT/UPDATE policies for those sensitive paths.

-- ---------------------------------------------------------------------------
-- Helper functions
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.owns_company(p_company_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.companies
    where id = p_company_id and owner_user_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------------
alter table public.profiles          enable row level security;
alter table public.companies         enable row level security;
alter table public.company_documents enable row level security;
alter table public.generators        enable row level security;
alter table public.rental_requests   enable row level security;
alter table public.payments          enable row level security;
alter table public.commission_config enable row level security;
alter table public.commissions       enable row level security;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create policy profiles_select_own on public.profiles
  for select using (id = auth.uid() or public.is_admin());
create policy profiles_insert_own on public.profiles
  for insert with check (id = auth.uid());
create policy profiles_update_own on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- companies  (owner manages own; customers see approved; admin sees all.
--             verification_status is changed by service role, not clients.)
-- ---------------------------------------------------------------------------
create policy companies_select on public.companies
  for select using (
    verification_status = 'approved'
    or owner_user_id = auth.uid()
    or public.is_admin()
  );
create policy companies_insert_own on public.companies
  for insert with check (owner_user_id = auth.uid());
create policy companies_update_own on public.companies
  for update using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- company_documents  (owner + admin only)
-- ---------------------------------------------------------------------------
create policy company_documents_select on public.company_documents
  for select using (public.owns_company(company_id) or public.is_admin());
create policy company_documents_insert on public.company_documents
  for insert with check (public.owns_company(company_id));
create policy company_documents_delete on public.company_documents
  for delete using (public.owns_company(company_id));

-- ---------------------------------------------------------------------------
-- generators  (public read only when available AND company approved;
--              owner manages own)
-- ---------------------------------------------------------------------------
create policy generators_select_public on public.generators
  for select using (
    (
      status = 'available'
      and exists (
        select 1 from public.companies c
        where c.id = generators.company_id
          and c.verification_status = 'approved'
      )
    )
    or public.owns_company(company_id)
    or public.is_admin()
  );
create policy generators_insert_own on public.generators
  for insert with check (public.owns_company(company_id));
create policy generators_update_own on public.generators
  for update using (public.owns_company(company_id)) with check (public.owns_company(company_id));
create policy generators_delete_own on public.generators
  for delete using (public.owns_company(company_id));

-- ---------------------------------------------------------------------------
-- rental_requests  (customer creates/reads own; company owner reads & updates)
-- ---------------------------------------------------------------------------
create policy rental_requests_select on public.rental_requests
  for select using (
    customer_id = auth.uid()
    or public.owns_company(company_id)
    or public.is_admin()
  );
create policy rental_requests_insert_customer on public.rental_requests
  for insert with check (customer_id = auth.uid());
-- customer can cancel their own; company owner can accept/reject/progress.
create policy rental_requests_update on public.rental_requests
  for update using (
    customer_id = auth.uid() or public.owns_company(company_id)
  ) with check (
    customer_id = auth.uid() or public.owns_company(company_id)
  );

-- ---------------------------------------------------------------------------
-- payments  (read only; writes via service role / Edge Functions)
-- ---------------------------------------------------------------------------
create policy payments_select on public.payments
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.rental_requests r
      where r.id = payments.rental_request_id
        and (r.customer_id = auth.uid() or public.owns_company(r.company_id))
    )
  );

-- ---------------------------------------------------------------------------
-- commission_config  (admin only; service role writes)
-- ---------------------------------------------------------------------------
create policy commission_config_select_admin on public.commission_config
  for select using (public.is_admin());

-- ---------------------------------------------------------------------------
-- commissions  (read by the related company owner & admin; writes via service role)
-- ---------------------------------------------------------------------------
create policy commissions_select on public.commissions
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.rental_requests r
      where r.id = commissions.rental_request_id
        and public.owns_company(r.company_id)
    )
  );
