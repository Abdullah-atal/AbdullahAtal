-- Run after schema.sql
-- Product image storage. Supabase Storage metadata should be managed through the Storage API.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('product-images','product-images',true,5242880,array['image/png','image/jpeg','image/webp'])
on conflict (id) do nothing;

create policy "public read product images" on storage.objects
for select using (bucket_id='product-images');

create policy "seller upload product images" on storage.objects
for insert to authenticated
with check (
 bucket_id='product-images'
 and (storage.foldername(name))[1]=(select auth.uid()::text)
);

create policy "seller update product images" on storage.objects
for update to authenticated
using (bucket_id='product-images' and owner_id=(select auth.uid()::text))
with check (bucket_id='product-images' and owner_id=(select auth.uid()::text));

create policy "seller delete product images" on storage.objects
for delete to authenticated
using (bucket_id='product-images' and owner_id=(select auth.uid()::text));
