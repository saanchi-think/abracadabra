-- =====================================================================
-- Think Technologies · Client Portal — database schema
-- Run this in Supabase → SQL Editor → New query → paste → Run.
-- =====================================================================

-- One row per client. `slug` powers the unique portal URL (?client=<slug>).
create table if not exists public.clients (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  name        text not null,
  domain      text,                 -- e.g. acme.com (used to fetch the logo)
  logo_url    text,                 -- resolved company logo
  tagline     text,
  created_at  timestamptz not null default now()
);

alter table public.clients enable row level security;

-- ---------------------------------------------------------------------
-- PROTOTYPE POLICIES — open read/write so we can build & test quickly.
-- ⚠️  We replace these with auth-scoped policies when we add login
--     (Think staff = full access, each client = only their own row).
-- ---------------------------------------------------------------------
drop policy if exists "prototype read"   on public.clients;
drop policy if exists "prototype insert" on public.clients;
drop policy if exists "prototype update" on public.clients;
drop policy if exists "prototype delete" on public.clients;

create policy "prototype read"   on public.clients for select using (true);
create policy "prototype insert" on public.clients for insert with check (true);
create policy "prototype update" on public.clients for update using (true);
create policy "prototype delete" on public.clients for delete using (true);
