-- Public bucket for generator photos (no signed URLs needed)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'generator-photos',
  'generator-photos',
  true,
  8388608,  -- 8 MB per photo
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do nothing;

-- Company owners can upload to their company folder: {company_id}/{generator_id}/...
create policy "owner_upload_photos" on storage.objects
  for insert with check (
    bucket_id = 'generator-photos'
    and exists (
      select 1 from companies
      where id::text = split_part(name, '/', 1)
        and owner_user_id = auth.uid()
    )
  );

-- Anyone can read generator photos (public marketplace)
create policy "public_read_photos" on storage.objects
  for select using (bucket_id = 'generator-photos');

-- Owners can delete their own photos
create policy "owner_delete_photos" on storage.objects
  for delete using (
    bucket_id = 'generator-photos'
    and exists (
      select 1 from companies
      where id::text = split_part(name, '/', 1)
        and owner_user_id = auth.uid()
    )
  );
