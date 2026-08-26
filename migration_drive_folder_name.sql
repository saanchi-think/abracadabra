-- Show the actual Drive folder name next to each client in admin.html, so
-- staff can eyeball at a glance whether the linked folder is the right one.
-- Run this in Supabase → SQL Editor.
alter table public.clients
  add column if not exists drive_folder_name text;
