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
