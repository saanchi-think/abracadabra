-- "See Our Work" tab: client requests to see relevant past work by industry
-- area(s) + a free-text note. Notifies staff by email via n8n (portal-work-request).
create table if not exists work_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  requester_name text,
  areas text[] not null default '{}',
  note text,
  created_at timestamptz not null default now()
);
alter table work_requests enable row level security;
create policy "work_requests public write" on work_requests for insert to public with check (true);
create policy "work_requests staff read" on work_requests for select to public using (is_staff());
