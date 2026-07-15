# Meeting transcript backfill (Lafayette American) — one-time, July 2026

Backfilled 2 real historical meetings for Lafayette American by reading their
actual call transcripts from the shared Drive folder and generating
client-safe summaries (excluding all internal Think Technologies business,
other clients, revenue/staffing talk — only what's relevant to this client).

## What was added
- **Collaboration Opportunities** — May 29, 2026
- **AI Needs Assessment** — June 8, 2026

## What was excluded and why
- **"Weekly meeting" (Jun 9, 2026)** — internal Think Technologies team
  meeting (no Lafayette attendees on the invite; content was about pricing
  and business model strategy). Not a real Lafayette meeting.
- **"LA - Notes For Call Today"** — undated prep/talking-points doc, not a
  transcript of a completed meeting.

## How it was done
1. Used the existing "Meeting Notes Taker" workflow's proven patterns
   (without modifying that workflow): the Google Drive doc-export-as-text
   HTTP request, and the existing OpenAI credential ("OpenAI account 2").
2. Built two TEMPORARY n8n workflows (since deleted, per one-time-backfill
   scope): one to export a Google Doc's text, one to run it through a
   strict "extract only client-relevant content" prompt (gpt-4o-mini).
3. Verified each summary against the raw transcript by hand before
   inserting into the `meetings` table.

## To repeat this for another client
The exact prompt used (with `{{ $json.body.clientName }}` and
`{{ $json.body.transcript }}` as inputs) is preserved in this session's
history — ask to rebuild the two temp workflows if you want to backfill
another client's meeting history the same way.
