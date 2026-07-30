# n8n workflows (exports)

Exports of the n8n workflows that power the portal, kept here so the repo stays the source of truth. Live copies run on `https://n8n.srv1000837.hstgr.cloud`.

## The full client lifecycle (Jul 30, 2026)

```
1. Company fills out intake.html
      → portal AUTO-CREATED in the admin panel (clients + login invitation)
      → team emailed the submission (voice note attached if recorded)
      → NOTHING sent to the client
2. Staff link the client's Drive folder (admin.html — Add-client field, or "Set" on the row)
      → Internal/ + External/ subfolders auto-created within 30 min
3. Staff file client-facing docs in External/ (signed contracts, proposals, media)
      → they appear in the client's Proposals & Media / Contract tabs
      → signed-PDF rule: unsigned versions of an agreement are auto-hidden
4. New Gemini meeting notes land in the client's folder
      → client-safe summary auto-published to Meeting Notes (team emailed to review; Edit/Hide in portal)
      → client action items extracted to the Action Center (latest meeting only)
5. When ready to hand over: email ai@think-technologies.com
      subject: send portal <company name>
      → client gets their portal link from ai@, staff gets confirmation
      ⚠ workflow is INACTIVE until hosting is live — see checklist below
```

## Workflow exports in this folder

| File | Live status | Purpose |
|---|---|---|
| think-intake-form.json | ACTIVE | intake.html → auto-create portal + email team |
| client-folder-provisioning.json | ACTIVE | auto-create Internal/External for every linked client (30 min) |
| think-portal-drive-files.json | ACTIVE | Proposals & Media / Contract tabs (External-only + signed-contract rule) |
| think-portal-meeting-notes-sync.json | ACTIVE | Gemini notes → client-safe Meeting Notes entries (30 min) |
| think-portal-client-action-items.json | ACTIVE (re-enabled Jul 30 by Kavya) | transcripts → Action Center items |
| think-portal-feedback-notify.json | ACTIVE | Live Feedback comment → team email |
| think-portal-send-on-request.json | **INACTIVE — do not activate until hosting is live** | "send portal <company>" email → client delivery |

## Launch checklist (for Saanchi)

1. Enable hosting (Settings → Pages → main / root) — the send-portal workflow assumes `https://saanchi-think.github.io/abracadabra/`
2. Run `status.sql` in Supabase SQL Editor (enables Live Feedback comments; consider prototype-open policies to match other tables until auth is finalized)
3. Cleanup: delete "ZZ Intake Pipeline Test Co" (admin panel) and purge pre-Jul-30 Tribe rows from client_actions (SQL in commit 72ce6e1's message)
4. Then activate "Send Portal On Request" in n8n — test with a dummy client first

## Re-importing

n8n → Workflows → ⋯ → Import from File. Re-attach the Google Drive / Gmail / OpenAI credentials on any node showing a warning, then Activate. Supabase keys inside are the public (anon) key — same as the portal HTML embeds.
