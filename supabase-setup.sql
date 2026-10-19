-- quest.exe sync setup: paste into Supabase → SQL Editor → New query → Run
-- 1) change the two emails at the bottom first

create table if not exists public.members (email text primary key);
alter table public.members enable row level security;  -- no policies: the app can't read or change this list

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.members m where m.email = lower(auth.jwt() ->> 'email'));
$$;

create table if not exists public.docs (
  id text primary key,
  kind text not null,
  data jsonb,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.docs enable row level security;

drop policy if exists "members read" on public.docs;
drop policy if exists "members add" on public.docs;
drop policy if exists "members change" on public.docs;
create policy "members read"   on public.docs for select to authenticated using (public.is_member());
create policy "members add"    on public.docs for insert to authenticated with check (public.is_member());
create policy "members change" on public.docs for update to authenticated using (public.is_member()) with check (public.is_member());

create or replace function public.docs_touch() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = clock_timestamp(); return new; end $$;
drop trigger if exists docs_touch on public.docs;
create trigger docs_touch before insert or update on public.docs for each row execute function public.docs_touch();

do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

insert into public.members (email) values
  (lower('KAYLA_EMAIL_HERE')),
  (lower('ELLIOT_EMAIL_HERE'))
on conflict do nothing;
