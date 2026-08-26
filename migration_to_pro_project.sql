-- =====================================================================
-- FULL MIGRATION: think-portal-demo → Think Technologies Pro project
-- Run this ONCE, in order, in the NEW project's SQL Editor.
--
-- Deliberately NOT migrated (should start fresh in the new project):
--   • auth.users / profiles — staff self-serve signup (email + shared
--     password "Think@2026") auto-creates these via the triggers below.
--   • processed_transcripts / processed_emails — dedupe/audit tables;
--     starting empty means nothing gets silently skipped.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- SCHEMA
-- ---------------------------------------------------------------------
create table public.clients (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  domain text,
  logo_url text,
  tagline text,
  created_at timestamptz not null default now(),
  logo_on_light boolean not null default false,
  drive_folder_id text,
  drive_folder_name text,
  live_artifact_url text
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'none',
  client_id uuid references public.clients(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.invitations (
  email text primary key,
  role text not null,
  client_id uuid references public.clients(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.meetings (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  title text,
  meeting_date date,
  time_label text,
  location text,
  upcoming boolean not null default false,
  points jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  start_time text,
  end_time text,
  tz text,
  calendar_event_id text,
  hidden boolean not null default false,
  minutes_ready boolean not null default false
);

create table public.meeting_comments (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  author_name text,
  author_role text,
  body text not null,
  created_at timestamptz not null default now(),
  parent_id uuid references public.meeting_comments(id) on delete cascade
);

create table public.meeting_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  requester_name text,
  preferred_date date,
  preferred_start text,
  preferred_end text,
  note text,
  status text not null default 'pending',
  staff_message text,
  created_at timestamptz not null default now(),
  preferred_tz text,
  target_meeting_id uuid references public.meetings(id) on delete set null
);

create table public.client_actions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  name text not null,
  note text,
  status text not null default 'pending',
  source_doc_id text,
  created_at timestamptz not null default now()
);

create table public.processed_transcripts (
  doc_id text primary key,
  client_id uuid references public.clients(id) on delete cascade,
  processed_at timestamptz not null default now()
);

create table public.processed_emails (
  message_id text primary key,
  client_id uuid not null references public.clients(id) on delete cascade,
  processed_at timestamptz not null default now()
);

create table public.work_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  requester_name text,
  areas text[] not null default '{}',
  note text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- FUNCTIONS
-- ---------------------------------------------------------------------
create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'staff');
$$;

create or replace function public.my_client_id() returns uuid
language sql stable security definer set search_path = public as $$
  select client_id from public.profiles where id = auth.uid();
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare inv record;
begin
  select * into inv from public.invitations where lower(email) = lower(new.email);
  insert into public.profiles (id, email, role, client_id)
  values (new.id, new.email, coalesce(inv.role, 'none'), inv.client_id)
  on conflict (id) do nothing;
  return new;
end; $$;

create or replace function public.auto_staff_on_signup()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.email ilike '%@think-technologies.com' then
    insert into public.profiles (id, role) values (new.id, 'staff')
    on conflict (id) do update set role = 'staff';
  end if;
  return new;
end; $$;

create or replace function public.n8n_mark_action_done(p_action_id uuid, p_evidence text)
returns void language sql security definer set search_path = public as $$
  update public.client_actions
  set status = 'done',
      note = coalesce(nullif(note, ''), '') || (case when coalesce(note, '') = '' then '' else E'\n\n' end) || 'Auto-marked done from email: ' || coalesce(p_evidence, '(no evidence provided)')
  where id = p_action_id;
$$;
grant execute on function public.n8n_mark_action_done(uuid, text) to anon, authenticated;

-- Trigger order matters: alphabetical, so handle_new_user runs first and
-- sets role from invitations; auto_staff_on_signup then only overrides for
-- @think-technologies.com emails.
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
create trigger on_auth_user_created_auto_staff after insert on auth.users
  for each row execute function public.auto_staff_on_signup();

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.clients enable row level security;
alter table public.profiles enable row level security;
alter table public.invitations enable row level security;
alter table public.meetings enable row level security;
alter table public.meeting_comments enable row level security;
alter table public.meeting_requests enable row level security;
alter table public.client_actions enable row level security;
alter table public.processed_transcripts enable row level security;
alter table public.processed_emails enable row level security;
alter table public.work_requests enable row level security;

create policy "clients public read" on public.clients for select using (true);
create policy "clients write" on public.clients for all using (is_staff()) with check (is_staff());

create policy "profiles self read" on public.profiles for select using (id = auth.uid() or is_staff());

create policy "invitations staff" on public.invitations for all using (is_staff()) with check (is_staff());
create policy "invitations public client email read" on public.invitations for select using (role = 'client');

create policy "meetings public read" on public.meetings for select using (true);
create policy "meetings client" on public.meetings for select using (client_id = my_client_id());
create policy "meetings staff" on public.meetings for all using (is_staff()) with check (is_staff());

create policy "mcomments public read" on public.meeting_comments for select using (true);
create policy "mcomments client read" on public.meeting_comments for select using (client_id = my_client_id());
create policy "mcomments public write" on public.meeting_comments for insert with check (true);
create policy "mcomments client write" on public.meeting_comments for insert with check (client_id = my_client_id());
create policy "mcomments staff" on public.meeting_comments for all using (is_staff()) with check (is_staff());

create policy "mreq public read" on public.meeting_requests for select using (true);
create policy "mreq client read" on public.meeting_requests for select using (client_id = my_client_id());
create policy "mreq public write" on public.meeting_requests for insert with check (true);
create policy "mreq client write" on public.meeting_requests for insert with check (client_id = my_client_id());
create policy "mreq staff" on public.meeting_requests for all using (is_staff()) with check (is_staff());

create policy "cactions public read" on public.client_actions for select using (true);
create policy "cactions public write" on public.client_actions for insert with check (true);
create policy "cactions staff" on public.client_actions for all using (is_staff()) with check (is_staff());

create policy "ptranscripts public read" on public.processed_transcripts for select using (true);
create policy "ptranscripts public write" on public.processed_transcripts for insert with check (true);

create policy "processed_emails public read" on public.processed_emails for select using (true);
create policy "processed_emails public write" on public.processed_emails for insert with check (true);

create policy "work_requests public write" on public.work_requests for insert with check (true);
create policy "work_requests staff read" on public.work_requests for select using (is_staff());

-- ---------------------------------------------------------------------
-- STORAGE
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- DATA — real client/portal content, IDs preserved for referential integrity
-- ---------------------------------------------------------------------
insert into public.clients (id, slug, name, domain, logo_url, tagline, created_at, logo_on_light, drive_folder_id, drive_folder_name, live_artifact_url) values
('32545d98-61d7-4429-a7ef-49854743f556','lafayette','lafayette','lafayetteamerican.com','https://cdn.brandfetch.io/lafayetteamerican.com/w/400/h/400/type/icon/fallback/transparent?c=1id0MMCBxRhX8u81xkT',null,'2026-07-13T16:52:07.944673+00:00',true,null,null,null),
('f6982856-5970-415f-bd1e-dde123f66e34','thirdthursday','Thirdthursday','thirdthursday.live','https://cdn.brandfetch.io/thirdthursday.live/w/400/h/400/type/icon/fallback/transparent?c=1id0MMCBxRhX8u81xkT',null,'2026-08-24T22:10:43.796876+00:00',true,'1T98wDYHOaKHQ38mbUCQVQD8QoSzl7qDN','Third Thursdays',null),
('c27f9541-1a82-4cac-968e-78d488445ac7','tribe','Tribe','tribedevelopment.city','https://www.google.com/s2/favicons?domain=tribedevelopment.city&sz=128',null,'2026-07-13T16:33:23.323468+00:00',false,'1gBOBgjTInHJO4WAcQxglRcNRncYKI7J3','Tribe Development City',null);

insert into public.invitations (email, role, client_id, created_at) values
('saanchi.2000@gmail.com','client','32545d98-61d7-4429-a7ef-49854743f556','2026-07-21T16:49:17.888099+00:00'),
('kavya@think-technologies.com','client','c27f9541-1a82-4cac-968e-78d488445ac7','2026-07-21T21:01:36.543535+00:00'),
('ai@think-technologies.com','client','f6982856-5970-415f-bd1e-dde123f66e34','2026-08-24T22:10:43.912122+00:00');

insert into public.meetings (id, client_id, title, meeting_date, time_label, location, upcoming, points, created_at, start_time, end_time, tz, calendar_event_id, hidden, minutes_ready) values
('149ce9a4-e053-4212-a558-e43155b1724c','c27f9541-1a82-4cac-968e-78d488445ac7','TRIBE Next Steps Follow-Up','2026-07-28',null,null,false,'["Aligned on automating deal intake: a centralized intake form comes first, email parsing later. Property data to capture includes location, size, building features, zoning, parking, condition, and images.","Deal statuses will be managed manually on the board for flexibility, with entries automatically moving to a sub-board once a status is selected.","Agreed on automated follow-up reminders after one week of no contact, with notifications going to the whole team; email is the primary channel, and text notifications are under review.","First impressions of the intelligence board were positive — Tribe will review it internally and send formal feedback.","Next steps: Brandon sends the deal stages/classifications list and the board feedback; Think comes back with an implementation timeline."]'::jsonb,'2026-07-30T18:18:27.69084+00:00',null,null,null,null,false,true),
('d08449b9-538e-4801-bf26-287eccbfb6e7','32545d98-61d7-4429-a7ef-49854743f556','Collaboration Opportunities','2026-05-29',null,null,false,'["Discussed operational challenges faced by Lafayette American, including siloed teams and manual workflows, and the need for an integrated technical infrastructure.","Proposed a consulting strategy focusing on initial assessments to identify quick wins, followed by establishing standard tools and custom agents to improve operations.","Emphasized the importance of expert guidance for Lafayette American''s team to elevate their use of AI tools effectively.","Scheduled a follow-up meeting for Friday, June 5th at 1:00 PM, to further discuss and assess Lafayette American''s needs.","Jackie proposed a show and tell session to demonstrate current tools, which was agreed upon as a means to identify AI deployment."]'::jsonb,'2026-07-15T17:35:08.820886+00:00',null,null,null,null,false,true),
('9158f0df-5cdb-4469-9cfd-a1874f8e7f5e','32545d98-61d7-4429-a7ef-49854743f556','AI Needs Assessment','2026-06-08',null,null,false,'["Discussed the agency''s current AI adoption stage, emphasizing the need for standardized tools and workflows to enhance operational efficiency.","Identified gaps in the technology stack, focusing on strategic brief writing and content planning as critical areas for improvement.","Agreed to recommend ChatGPT Business as a solution for addressing security risks and improving documentation processes.","Next steps include sending a proposal and relevant case studies, with a formal investment decision anticipated by July."]'::jsonb,'2026-07-15T17:35:08.820886+00:00',null,null,null,null,false,true),
('f8768f55-5456-43dc-ae7b-d4d88eb2eea7','c27f9541-1a82-4cac-968e-78d488445ac7','Discovery Call','2025-11-07',null,null,false,'["Walked through Tribe Development''s three business lines — real estate development, nonprofit consulting, and the new brokerage — and where administrative time is going today.","Identified the top pain points: distilling meetings into clear action items, CRM and lead management, and transcribing contractor expense documents (PDF images) into usable formats.","Discussed automation directions: meeting summaries wired into the CRM and project boards, PDF expense transcription into spreadsheets, and an internal FAQ assistant trained on Tribe''s deal knowledge.","Explored standardized deal workflows to keep the deal team (contractors, architects, legal counsel) organized and accountable on action items.","Agreed to focus on data organization and automation readiness ahead of a Q1 2026 implementation."]'::jsonb,'2026-07-30T17:44:54.988771+00:00',null,null,null,null,false,true),
('d6e5326c-84f6-446e-8731-2ff5e0d3672d','c27f9541-1a82-4cac-968e-78d488445ac7','Automation Proposal Review','2025-12-05',null,null,false,'["Reviewed a two-phase engagement: Phase 1 assesses current workflows, data structures, and business processes to identify the highest-impact automation opportunities; Phase 2 covers data organization and platform setup for AI readiness.","Walked through the three proposed workflows: Automated Meeting Intelligence, a Deal Cut Sheet Generator, and Expense & Invoice Processing Automation (OCR-based).","Brandon approved the $6,000 project with a $200/month maintenance plan.","Brandon offered to connect the team with potential referrals at Invest Detroit."]'::jsonb,'2026-07-30T17:44:54.988771+00:00',null,null,null,null,false,true),
('19be9252-90e5-49f1-b580-e35fb6959aef','c27f9541-1a82-4cac-968e-78d488445ac7','AI Readiness Assessment Kickoff','2026-04-08',null,null,false,'["Kicked off the Phase 1 AI Readiness Assessment — reviewed how work flows across the three business lines and where manual data-gathering slows property evaluations.","Reviewed the client-intake survey end to end; intake data isn''t connected to a CRM yet, so matching clients to properties is a manual cross-referencing process.","Prioritized standing up a CRM for client intake before building the more complex map-based dashboard, and explored a scoring/matchmaking index to rank property fits.","Next steps: Tribe shares the ~10 websites used for property research plus a stakeholder-mapping walkthrough; Think investigates map/data integration options and CRM candidates."]'::jsonb,'2026-07-30T17:44:54.988771+00:00',null,null,null,null,false,true),
('d16b9389-e6e5-4585-bae8-69230ce9aea0','32545d98-61d7-4429-a7ef-49854743f556','Meeting with Lafayette','2026-09-01','6:30 PM – 7:00 PM EDT','Google Meet',false,'["hi"]'::jsonb,'2026-08-24T21:42:00.775296+00:00','18:30','19:00','America/Detroit','0fk9k41elaj2518jevppf6a9ec',false,false);

insert into public.meeting_comments (id, meeting_id, client_id, author_name, author_role, body, created_at, parent_id) values
('54ed8867-b739-4e8d-b88d-0456bb38a497','9158f0df-5cdb-4469-9cfd-a1874f8e7f5e','32545d98-61d7-4429-a7ef-49854743f556','lafayette','client','Can we get the ChatGPT Business pricing breakdown before Friday''s call?','2026-07-16T16:54:10.335905+00:00',null),
('1b86e66e-7d12-42a6-a771-1121f1ff1c47','9158f0df-5cdb-4469-9cfd-a1874f8e7f5e','32545d98-61d7-4429-a7ef-49854743f556','Think Technologies','think','Yes — we''ll have the pricing breakdown over to you by end of week.','2026-07-21T18:59:49.317117+00:00','54ed8867-b739-4e8d-b88d-0456bb38a497'),
('6f649338-9fad-45ff-b812-eb86fec2a019','9158f0df-5cdb-4469-9cfd-a1874f8e7f5e','32545d98-61d7-4429-a7ef-49854743f556','Lafayette','client','Thanks for the recap! Excited to move forward with this.','2026-07-21T20:21:52.319491+00:00',null),
('4d468679-b6f6-4eea-a18e-062449ee8a91','9158f0df-5cdb-4469-9cfd-a1874f8e7f5e','32545d98-61d7-4429-a7ef-49854743f556','Think Technologies','think','abcdss','2026-07-23T20:11:44.050641+00:00','6f649338-9fad-45ff-b812-eb86fec2a019'),
('e27c4841-79ee-4226-b4b7-75eec00d1f68','9158f0df-5cdb-4469-9cfd-a1874f8e7f5e','32545d98-61d7-4429-a7ef-49854743f556','Think Technologies','think','okay','2026-08-24T21:10:06.276708+00:00','6f649338-9fad-45ff-b812-eb86fec2a019'),
('9596e3b2-e250-40f0-8f61-d720063c1311','9158f0df-5cdb-4469-9cfd-a1874f8e7f5e','32545d98-61d7-4429-a7ef-49854743f556','Lafayette','client','nooo','2026-08-24T21:10:18.533554+00:00',null),
('545fafdb-bd3a-490a-a8a4-373c78150000','9158f0df-5cdb-4469-9cfd-a1874f8e7f5e','32545d98-61d7-4429-a7ef-49854743f556','Lafayette','client','yoyo','2026-08-24T21:51:51.971134+00:00',null),
('afcaf0ff-d7a0-48d1-98ad-32b2c11dc565','9158f0df-5cdb-4469-9cfd-a1874f8e7f5e','32545d98-61d7-4429-a7ef-49854743f556','Think Technologies','think','okay','2026-08-24T22:59:07.934503+00:00','545fafdb-bd3a-490a-a8a4-373c78150000');

insert into public.meeting_requests (id, client_id, requester_name, preferred_date, preferred_start, preferred_end, note, status, staff_message, created_at, preferred_tz, target_meeting_id) values
('37968885-d712-4b31-be21-3135f822568a','32545d98-61d7-4429-a7ef-49854743f556','Lafayette','2026-09-01','17:30','18:00','hi','accepted',null,'2026-08-24T21:41:16.947345+00:00','America/Detroit',null);

insert into public.client_actions (id, client_id, name, note, status, source_doc_id, created_at) values
('0059fee2-2ec2-4a61-b7b1-5e475833b15b','c27f9541-1a82-4cac-968e-78d488445ac7','Provide file structure','Brandon Hodges will provide access to the file structure needed for the assessment.','pending','1IuTZlasH-KmaZ93S6wnUr7SyMkVr5fhwT4f-0-1iTc8','2026-07-21T18:23:13.137977+00:00'),
('3b2926a7-b6b0-483f-b8df-e49031607873','c27f9541-1a82-4cac-968e-78d488445ac7','List Websites','Provide the 10 websites currently used for manually gathering property information.','pending','1frW2_0pu4kRgP5yy2o4KgID0AbyKMnmrIkbx4s4HybQ','2026-07-21T18:23:13.138761+00:00'),
('0795fe2e-6070-4e44-a4ad-fcdae4173140','c27f9541-1a82-4cac-968e-78d488445ac7','Map Stakeholders','Prepare an example walkthrough for stakeholder mapping specific to the brokerage workflow.','pending','1frW2_0pu4kRgP5yy2o4KgID0AbyKMnmrIkbx4s4HybQ','2026-07-21T18:23:13.138761+00:00'),
('71534e9e-cd35-46d8-8f64-8b7e9d8bf45e','c27f9541-1a82-4cac-968e-78d488445ac7','Share workflow details','Brandon Hodges will share details about current workflows from start to finish for better understanding.','pending','1IuTZlasH-KmaZ93S6wnUr7SyMkVr5fhwT4f-0-1iTc8','2026-07-21T18:23:13.137977+00:00'),
('2f78e0ec-a0b9-4afc-9102-67bf9d6d06ce','c27f9541-1a82-4cac-968e-78d488445ac7','Assess Questionnaire','Review the current client intake form to determine if questions suffice for matchmaking recommendations.','pending','1frW2_0pu4kRgP5yy2o4KgID0AbyKMnmrIkbx4s4HybQ','2026-07-21T18:23:13.138761+00:00'),
('89cebb12-2c28-46b0-9d79-86819a24ba34','c27f9541-1a82-4cac-968e-78d488445ac7','Investigate Map Integration','Work on map view data collection and check websites for APIs and available information.','pending','1frW2_0pu4kRgP5yy2o4KgID0AbyKMnmrIkbx4s4HybQ','2026-07-21T18:23:13.138761+00:00'),
('db228ffd-c0ab-421a-9b30-0c2e8cae0531','c27f9541-1a82-4cac-968e-78d488445ac7','Record or shadow meeting','Brandon Hodges will either record a meeting or allow shadowing to gain insights into daily processes.','pending','1IuTZlasH-KmaZ93S6wnUr7SyMkVr5fhwT4f-0-1iTc8','2026-07-21T18:23:13.137977+00:00'),
('680a5bf3-61cd-43db-83b2-7296d74f38ac','c27f9541-1a82-4cac-968e-78d488445ac7','Select CRM System','Research and select a Customer Relationship Management system for client intake form data.','pending','1frW2_0pu4kRgP5yy2o4KgID0AbyKMnmrIkbx4s4HybQ','2026-07-21T18:23:13.138761+00:00'),
('27d62a76-153f-476b-b251-d1ef1a70134e','c27f9541-1a82-4cac-968e-78d488445ac7','Connect to Invest Detroit','Brandon Hodges will connect the team with potential referrals at Invest Detroit (IDB).','pending','1IuTZlasH-KmaZ93S6wnUr7SyMkVr5fhwT4f-0-1iTc8','2026-07-21T18:23:13.137977+00:00'),
('ab9baf97-2f8f-4e1b-aabf-f350ec871946','c27f9541-1a82-4cac-968e-78d488445ac7','Send Project Assets','Send the current client survey and provide prioritized list of relevant website sources and data sets.','pending','1frW2_0pu4kRgP5yy2o4KgID0AbyKMnmrIkbx4s4HybQ','2026-07-21T18:23:13.138761+00:00'),
('95560a1d-8d66-4e92-8b06-21b69a5cb638','c27f9541-1a82-4cac-968e-78d488445ac7','Re-evaluate document drive','Brandon Hodges will ensure document consistency over the holidays.','pending','1iSx8l-73zJ0u4V-jnU2QyiNoIAE0tcaic89M2MMajow','2026-07-21T18:23:13.192379+00:00'),
('5f14a994-cfbc-4c03-8129-2e54faa34459','c27f9541-1a82-4cac-968e-78d488445ac7','List Deal Stages','Draft the specific stages and classifications for the deal tracking process, and reply to Kavya''s email with the list.','done','1oRw6adRPWJgO69vkDidsIODZBSaKwNu53o0DVGAAWUA','2026-07-30T18:10:17.899903+00:00'),
('231f326c-8e97-476d-bfd4-5aa642cf15d5','c27f9541-1a82-4cac-968e-78d488445ac7','Provide Board Feedback','Review the intelligence board with your team and send over feedback after discussing it internally.','pending','1oRw6adRPWJgO69vkDidsIODZBSaKwNu53o0DVGAAWUA','2026-07-30T18:10:17.899903+00:00'),
('7fd1ce55-38bb-4141-967a-e4d531e37909','32545d98-61d7-4429-a7ef-49854743f556','Prepare Show and Tell','Jackie will gather existing tools and documentation for a demonstration of current agency processes.','done','1uPp74htQnDGuf-t1M9m5Srn4Rzdu8HytsohmJUupSq8','2026-07-15T22:10:06.13551+00:00'),
('eef990ef-04b1-4cf2-9d48-85e46a80d6b3','32545d98-61d7-4429-a7ef-49854743f556','Send Deck','Deliver the 4 slides regarding agency AI adoption tools and current technology stack.','done','121wuLndC_0cF-_vqkXar9ix2pUtYn7ZenrnFvcGeq-Y','2026-07-15T22:10:06.117665+00:00');

insert into public.work_requests (id, client_id, requester_name, areas, note, created_at) values
('4cac8982-d7d9-4a00-92a6-eee592b13aac','32545d98-61d7-4429-a7ef-49854743f556','Lafayette','{}','ddd','2026-08-24T22:54:49.292679+00:00'),
('5c4779c1-6abf-4ff6-ac69-6e517e544c81','32545d98-61d7-4429-a7ef-49854743f556','Lafayette','{Consulting}','rr','2026-08-25T03:27:02.371703+00:00');

-- Seed the first staff invite (matches original auth.sql) — anyone with a
-- @think-technologies.com email self-serves an account via admin.html
-- (shared password "Think@2026") and is auto-granted staff by the trigger.
insert into public.invitations (email, role) values ('saanchi@think-technologies.com', 'staff')
  on conflict (email) do update set role = 'staff';
