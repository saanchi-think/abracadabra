-- =====================================================================
-- Think Technologies · Client Portal — AUTH & ACCESS CONTROL
-- Run this in Supabase → SQL Editor AFTER schema.sql.
-- Adds roles, invitation-gated access, and locks down the clients table.
-- =====================================================================

-- Who each logged-in user is. role: 'staff' | 'client' | 'none'
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  role        text not null default 'none',
  client_id   uuid references public.clients(id) on delete set null,
  created_at  timestamptz not null default now()
);

-- Who is ALLOWED in, and as what. Access is granted only to invited emails.
create table if not exists public.invitations (
  email       text primary key,
  role        text not null,                         -- 'staff' | 'client'
  client_id   uuid references public.clients(id) on delete cascade,
  created_at  timestamptz not null default now()
);

-- On first login, build the user's profile from their matching invitation.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare inv record;
begin
  select * into inv from public.invitations where lower(email) = lower(new.email);
  insert into public.profiles (id, email, role, client_id)
  values (new.id, new.email, coalesce(inv.role, 'none'), inv.client_id)
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helpers (security definer → bypass RLS, so no policy recursion)
create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'staff');
$$;

create or replace function public.my_client_id() returns uuid
language sql stable security definer set search_path = public as $$
  select client_id from public.profiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- RLS: profiles — you can read your own; staff can read all
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
drop policy if exists "profiles self read" on public.profiles;
create policy "profiles self read" on public.profiles for select
  using (id = auth.uid() or public.is_staff());

-- ---------------------------------------------------------------------
-- RLS: invitations — staff only
-- ---------------------------------------------------------------------
alter table public.invitations enable row level security;
drop policy if exists "invitations staff" on public.invitations;
create policy "invitations staff" on public.invitations for all
  using (public.is_staff()) with check (public.is_staff());

-- ---------------------------------------------------------------------
-- RLS: clients — REPLACE the open prototype policies
--   • staff: full access to every client
--   • client: read only their own client row
-- ---------------------------------------------------------------------
drop policy if exists "prototype read"   on public.clients;
drop policy if exists "prototype insert" on public.clients;
drop policy if exists "prototype update" on public.clients;
drop policy if exists "prototype delete" on public.clients;

drop policy if exists "clients read"  on public.clients;
drop policy if exists "clients write" on public.clients;
create policy "clients read" on public.clients for select
  using (public.is_staff() or id = public.my_client_id());
create policy "clients write" on public.clients for all
  using (public.is_staff()) with check (public.is_staff());

-- ---------------------------------------------------------------------
-- Seed the first staff user(s). Edit / add your team's emails here.
-- They become staff automatically the first time they log in.
-- ---------------------------------------------------------------------
insert into public.invitations (email, role) values
  ('saanchi@think-technologies.com', 'staff')
on conflict (email) do update set role = 'staff';
