-- SECURITY FIX: "cactions public update" allowed ANY visitor (including
-- clients) to update any client_actions row directly via the API, bypassing
-- the UI entirely. Only staff should ever mark items done — drop it.
drop policy if exists "cactions public update" on client_actions;

-- Dedupe table for the email-based action-item sync (Think Portal — Email
-- Action Sync n8n workflow), mirroring processed_transcripts.
create table if not exists processed_emails (
  message_id text primary key,
  client_id uuid not null references clients(id) on delete cascade,
  processed_at timestamptz not null default now()
);
alter table processed_emails enable row level security;
create policy "processed_emails public write" on processed_emails for insert to public with check (true);
create policy "processed_emails public read" on processed_emails for select to public using (true);

-- Narrow, audited path for the email-sync workflow to mark an action item
-- done (the anon key alone can no longer UPDATE client_actions directly).
-- Only flips status + appends the evidence — cannot touch anything else.
create or replace function n8n_mark_action_done(p_action_id uuid, p_evidence text)
returns void
language sql
security definer
set search_path = public
as $$
  update client_actions
  set status = 'done',
      note = coalesce(nullif(note, ''), '') || (case when coalesce(note, '') = '' then '' else E'\n\n' end) || 'Auto-marked done from email: ' || coalesce(p_evidence, '(no evidence provided)')
  where id = p_action_id;
$$;
grant execute on function n8n_mark_action_done(uuid, text) to anon, authenticated;
