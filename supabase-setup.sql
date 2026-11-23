-- GingerBooks cloud sync: run once in Supabase > SQL Editor
create table if not exists public.books (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data       jsonb       not null,
  version    bigint      not null default 1,
  updated_at timestamptz not null default now()
);
alter table public.books enable row level security;
create policy "read own books"   on public.books for select using (auth.uid() = user_id);
create policy "insert own books" on public.books for insert with check (auth.uid() = user_id);
create policy "update own books" on public.books for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Newer Supabase projects do not grant table rights automatically.
grant usage on schema public to authenticated;
grant select, insert, update on public.books to authenticated;
revoke all on public.books from anon;

-- Attachments (bills, scans, PDFs): private bucket, each user only sees their own folder.
insert into storage.buckets (id, name, public, file_size_limit) values ('attachments','attachments', false, 10485760) on conflict (id) do nothing;
create policy "read own attachments" on storage.objects for select to authenticated using (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "add own attachments" on storage.objects for insert to authenticated with check (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "update own attachments" on storage.objects for update to authenticated using (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "delete own attachments" on storage.objects for delete to authenticated using (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text);
