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
-- Guest (view-only) access with an end date, enforced by the database.
create table if not exists public.book_guests (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid() references auth.users(id) on delete cascade,
  guest uuid not null references auth.users(id) on delete cascade,
  email text, name text,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  last_seen timestamptz,
  unique (owner, guest));
alter table public.book_guests enable row level security;
create policy "owner reads guests" on public.book_guests for select using (owner = auth.uid() or guest = auth.uid());
create policy "owner updates guests" on public.book_guests for update using (owner = auth.uid()) with check (owner = auth.uid());
create policy "owner deletes guests" on public.book_guests for delete using (owner = auth.uid());
grant select, update, delete on public.book_guests to authenticated;
create policy "guests read books" on public.books for select using (exists (select 1 from public.book_guests g where g.owner = books.user_id and g.guest = auth.uid() and g.expires_at > now()));
drop policy if exists "insert own books" on public.books;
create policy "insert own books" on public.books for insert with check (auth.uid() = user_id and not exists (select 1 from public.book_guests g where g.guest = auth.uid()));
create policy "guests read attachments" on storage.objects for select to authenticated using (bucket_id = 'attachments' and exists (select 1 from public.book_guests g where g.owner::text = (storage.foldername(name))[1] and g.guest = auth.uid() and g.expires_at > now()));
create or replace function public.guest_seen() returns void language sql security definer set search_path = public as $$ update public.book_guests set last_seen = now() where guest = auth.uid() $$;
revoke all on function public.guest_seen() from public, anon;
grant execute on function public.guest_seen() to authenticated;

-- Guests read through a filtered copy: optional financial-year limit, no worker personal details, no app password hashes.
alter table public.book_guests add column if not exists fy_from date, add column if not exists fy_to date;
drop policy if exists "guests read books" on public.books;
create or replace function public.guest_books() returns table(owner uuid, data jsonb, expires_at timestamptz, fy_from date, fy_to date)
language plpgsql security definer set search_path = public as $$
declare g public.book_guests%rowtype; d jsonb; k text;
begin
  select * into g from public.book_guests bg where bg.guest = auth.uid() and bg.expires_at > now() order by bg.created_at desc limit 1;
  if not found then return; end if;
  select b.data into d from public.books b where b.user_id = g.owner;
  if d is null then return; end if;
  if g.fy_from is not null then
    foreach k in array array['sales','purchases','salesReturns','purchaseReturns','orders','production','adjustments','receipts','expenses','bankTxns'] loop
      if d ? k then
        d := jsonb_set(d, array[k], coalesce((select jsonb_agg(e) from jsonb_array_elements(d->k) e where (e->>'date') >= g.fy_from::text and (e->>'date') <= coalesce(g.fy_to, '9999-12-31'::date)::text), '[]'::jsonb));
      end if;
    end loop;
  end if;
  if d ? 'workers' then
    d := jsonb_set(d, '{workers}', coalesce((select jsonb_agg(e - 'dob' - 'phone' - 'address' - 'idProof' - 'payTo' - 'emergency' - 'remarks') from jsonb_array_elements(d->'workers') e), '[]'::jsonb));
  end if;
  if d ? 'settings' then d := jsonb_set(d, '{settings,users}', '[]'::jsonb); end if;
  update public.book_guests set last_seen = now() where id = g.id;
  return query select g.owner, d, g.expires_at, g.fy_from, g.fy_to;
end $$;
revoke all on function public.guest_books() from public, anon;
grant execute on function public.guest_books() to authenticated;

