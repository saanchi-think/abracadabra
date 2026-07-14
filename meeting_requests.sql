-- =====================================================================
-- Think Technologies · Client Portal — MEETING REQUESTS (client → staff approval)
-- Run in Supabase → SQL Editor (after schema.sql + auth.sql + meetings.sql).
-- =====================================================================

create table if not exists public.meeting_requests (
  id              uuid primary key default gen_random_uuid(),
  client_id       uuid not null references public.clients(id) on delete cascade,
  requester_name  text,
  preferred_date  date,
  preferred_start text,          -- 'HH:MM'
  preferred_end   text,          -- 'HH:MM'
  note            text,          -- client's message
  status          text not null default 'pending',   -- pending | accepted | declined
  staff_message   text,          -- message emailed to client on decline
  created_at      timestamptz not null default now()
);
create index if not exists meeting_requests_client_idx on public.meeting_requests(client_id);

-- RLS: staff manage all; a client can create + read their own requests
alter table public.meeting_requests enable row level security;
drop policy if exists "mreq staff"        on public.meeting_requests;
drop policy if exists "mreq client read"  on public.meeting_requests;
drop policy if exists "mreq client write" on public.meeting_requests;
create policy "mreq staff" on public.meeting_requests for all
  using (public.is_staff()) with check (public.is_staff());
create policy "mreq client read" on public.meeting_requests for select
  using (client_id = public.my_client_id());
create policy "mreq client write" on public.meeting_requests for insert
  with check (client_id = public.my_client_id());
