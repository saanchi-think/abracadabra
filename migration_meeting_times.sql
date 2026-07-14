-- Structured start/end times on meetings (for calendar invites).
-- Run in Supabase → SQL Editor.
alter table public.meetings
  add column if not exists start_time text,
  add column if not exists end_time   text;
