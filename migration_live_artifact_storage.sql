-- Public storage bucket for staff-uploaded build zips (Live Feedback tab).
-- Client-side JS unzips the file and uploads each extracted file here, then
-- points clients.live_artifact_url at the resulting public URL.
-- Run this in Supabase → SQL Editor.
insert into storage.buckets (id, name, public) values ('live-artifacts', 'live-artifacts', true)
  on conflict (id) do nothing;

create policy "live-artifacts public read" on storage.objects for select
  to public using (bucket_id = 'live-artifacts');

create policy "live-artifacts staff write" on storage.objects for insert
  to public with check (bucket_id = 'live-artifacts' and is_staff());

create policy "live-artifacts staff update" on storage.objects for update
  to public using (bucket_id = 'live-artifacts' and is_staff());

create policy "live-artifacts staff delete" on storage.objects for delete
  to public using (bucket_id = 'live-artifacts' and is_staff());
