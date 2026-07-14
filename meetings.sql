-- =====================================================================
-- Think Technologies · Client Portal — MEETING NOTES
-- Run in Supabase → SQL Editor (after schema.sql + auth.sql).
-- =====================================================================

-- One row per meeting. `points` holds the bullet notes (array of strings).
-- `upcoming` = show this one in the "Next meeting" banner.
create table if not exists public.meetings (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid not null references public.clients(id) on delete cascade,
  title        text not null,
  meeting_date date,
  time_label   text,            -- e.g. "2:00–3:00 PM EST"
  location     text,            -- e.g. "Google Meet"
  upcoming     boolean not null default false,
  points       jsonb  not null default '[]'::jsonb,
  created_at   timestamptz not null default now()
);
create index if not exists meetings_client_idx on public.meetings(client_id);

-- Comments on a meeting (clients + staff).
create table if not exists public.meeting_comments (
  id           uuid primary key default gen_random_uuid(),
  meeting_id   uuid not null references public.meetings(id) on delete cascade,
  client_id    uuid not null references public.clients(id) on delete cascade,
  author_name  text,
  author_role  text,            -- 'client' | 'think'
  body         text not null,
  created_at   timestamptz not null default now()
);
create index if not exists meeting_comments_meeting_idx on public.meeting_comments(meeting_id);

-- ---------------------------------------------------------------------
-- RLS: staff manage everything; clients read their own + comment
-- ---------------------------------------------------------------------
alter table public.meetings enable row level security;
drop policy if exists "meetings staff"  on public.meetings;
drop policy if exists "meetings client" on public.meetings;
create policy "meetings staff"  on public.meetings for all
  using (public.is_staff()) with check (public.is_staff());
create policy "meetings client" on public.meetings for select
  using (client_id = public.my_client_id());

alter table public.meeting_comments enable row level security;
drop policy if exists "mcomments staff"        on public.meeting_comments;
drop policy if exists "mcomments client read"  on public.meeting_comments;
drop policy if exists "mcomments client write" on public.meeting_comments;
create policy "mcomments staff" on public.meeting_comments for all
  using (public.is_staff()) with check (public.is_staff());
create policy "mcomments client read" on public.meeting_comments for select
  using (client_id = public.my_client_id());
create policy "mcomments client write" on public.meeting_comments for insert
  with check (client_id = public.my_client_id());
