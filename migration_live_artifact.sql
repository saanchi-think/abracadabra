-- Live Feedback tab: staff can embed a live Claude artifact or Google Doc/Sheet/
-- Slides link so the client can view/interact with it directly in the portal.
-- Run this in Supabase → SQL Editor.
alter table public.clients
  add column if not exists live_artifact_url text;
