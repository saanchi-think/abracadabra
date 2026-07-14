-- =====================================================================
-- Think Technologies · Client Portal — STATUS (deliverables + discussion)
-- Run in Supabase → SQL Editor (after schema.sql + auth.sql).
-- =====================================================================

-- Deliverables tracked per client. status: 'done' | 'prog' | 'later'
create table if not exists public.deliverables (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references public.clients(id) on delete cascade,
  name        text not null,
  status      text not null default 'later',
  position    int  not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists deliverables_client_idx on public.deliverables(client_id);

-- Threaded discussion, optionally tagged to a deliverable/stage.
create table if not exists public.status_comments (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references public.clients(id) on delete cascade,
  tag         text,                 -- deliverable name, or null for general
  author_name text,
  author_role text,                 -- 'client' | 'think'
  body        text not null,
  parent_id   uuid references public.status_comments(id) on delete cascade,
  created_at  timestamptz not null default now()
);
create index if not exists status_comments_client_idx on public.status_comments(client_id);

-- ---------------------------------------------------------------------
-- RLS: staff manage everything; clients read their own + comment
-- ---------------------------------------------------------------------
alter table public.deliverables enable row level security;
drop policy if exists "deliverables staff"  on public.deliverables;
drop policy if exists "deliverables client" on public.deliverables;
create policy "deliverables staff"  on public.deliverables for all
  using (public.is_staff()) with check (public.is_staff());
create policy "deliverables client" on public.deliverables for select
  using (client_id = public.my_client_id());

alter table public.status_comments enable row level security;
drop policy if exists "scomments staff"       on public.status_comments;
drop policy if exists "scomments client read" on public.status_comments;
drop policy if exists "scomments client write" on public.status_comments;
create policy "scomments staff" on public.status_comments for all
  using (public.is_staff()) with check (public.is_staff());
create policy "scomments client read" on public.status_comments for select
  using (client_id = public.my_client_id());
create policy "scomments client write" on public.status_comments for insert
  with check (client_id = public.my_client_id());
