-- reports: dispute / abuse reports submitted by customers or owners
create table if not exists reports (
  id               uuid primary key default gen_random_uuid(),
  reporter_id      uuid not null references auth.users(id) on delete cascade,
  rental_request_id uuid references rental_requests(id) on delete set null,
  reported_entity_type text not null check (reported_entity_type in ('generator', 'company', 'user')),
  reported_entity_id uuid not null,
  reason           text not null check (reason in (
    'misrepresentation', 'no_show', 'damage', 'fraud', 'harassment', 'other'
  )),
  description      text,
  status           text not null default 'open' check (status in ('open', 'under_review', 'resolved', 'dismissed')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- updated_at trigger
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger reports_updated_at
  before update on reports
  for each row execute function set_updated_at();

-- RLS
alter table reports enable row level security;

-- reporter can insert their own reports
create policy "reporter_insert" on reports
  for insert with check (reporter_id = auth.uid());

-- reporter can view their own reports
create policy "reporter_select" on reports
  for select using (reporter_id = auth.uid());

-- service role can see all (admin panel uses service role via MCP)
create policy "admin_all" on reports
  for all using (
    exists (
      select 1 from profiles
      where id = auth.uid() and role = 'admin'
    )
  );
