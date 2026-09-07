-- Lets n8n's Meeting Notes Sync automation publish a meeting summary to a
-- client's portal, bypassing RLS the same way n8n_mark_action_done does for
-- client_actions. Direct POSTs to /rest/v1/meetings require staff auth
-- (RLS policy "meetings staff"), which the automation's anon key doesn't
-- have — this SECURITY DEFINER function is the sanctioned bypass.
create or replace function public.n8n_publish_meeting(
  p_client_id uuid,
  p_title text,
  p_meeting_date date,
  p_points jsonb
)
returns uuid
language sql
security definer
set search_path = public
as $$
  insert into public.meetings (client_id, title, meeting_date, upcoming, hidden, minutes_ready, points)
  values (p_client_id, p_title, p_meeting_date, false, false, true, p_points)
  returning id;
$$;
