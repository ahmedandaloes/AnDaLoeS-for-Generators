-- Add document_urls column to companies
alter table companies
  add column if not exists document_urls text[] not null default '{}';

-- Create private storage bucket for company verification docs
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'company-docs',
  'company-docs',
  false,
  10485760,  -- 10 MB per file
  array['image/jpeg','image/png','application/pdf']
)
on conflict (id) do nothing;

-- Storage RLS: path pattern is {user_id}/{company_id}/{filename}
-- Owner can upload to their own prefix
create policy "owner_upload_docs" on storage.objects
  for insert with check (
    bucket_id = 'company-docs'
    and auth.uid()::text = split_part(name, '/', 1)
  );

-- Owner can read their own docs
create policy "owner_read_docs" on storage.objects
  for select using (
    bucket_id = 'company-docs'
    and auth.uid()::text = split_part(name, '/', 1)
  );

-- Owner can delete their own docs
create policy "owner_delete_docs" on storage.objects
  for delete using (
    bucket_id = 'company-docs'
    and auth.uid()::text = split_part(name, '/', 1)
  );

-- Admins can read all docs
create policy "admin_read_all_docs" on storage.objects
  for select using (
    bucket_id = 'company-docs'
    and exists (
      select 1 from profiles
      where id = auth.uid() and role = 'admin'
    )
  );
