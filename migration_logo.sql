-- Adaptive logo display: remember whether a client's logo needs a light tile.
-- Run this in Supabase → SQL Editor.
alter table public.clients
  add column if not exists logo_on_light boolean not null default false;
