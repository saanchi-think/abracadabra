# Calendar invites via n8n + Google Calendar

When Think staff add a meeting (with a date + start time) and leave **"Email the client a calendar invite"** checked, the portal POSTs the meeting to an n8n webhook. n8n creates a Google Calendar event with the client as a guest — Google then emails them the invite and adds it to both calendars.

## Payload the portal sends (JSON)
```json
{
  "title": "Pilot proposal walkthrough",
  "description": "bullet notes, newline-separated",
  "location": "Google Meet",
  "start": "2026-07-20T18:00:00.000Z",   // ISO UTC
  "end":   "2026-07-20T19:00:00.000Z",
  "timezone": "America/New_York",
  "attendeeEmail": "contact@acme.com",    // the client's login email
  "clientName": "Acme Corp",
  "organizer": "Think Technologies"
}
```

## n8n workflow (2 nodes)

**1. Webhook node**
- HTTP Method: **POST**
- Path: anything, e.g. `portal-meeting`
- Respond: **Immediately**
- Options → **Allowed Origins (CORS): `*`**  ← important, so the browser can call it
- Copy the **Production URL** it shows — that's what you give back to me.

**2. Google Calendar → "Create an Event" node**
- Credential: your Think Google account (authorize if needed)
- Calendar: your Think calendar
- Start: `{{ $json.body.start }}`
- End: `{{ $json.body.end }}`
- Additional Fields:
  - Summary/Title: `{{ $json.body.title }}`
  - Description: `{{ $json.body.description }}`
  - Location: `{{ $json.body.location }}`
  - Attendees: `{{ $json.body.attendeeEmail }}`
  - **Send Updates / Send Notifications: All** ← this makes Google email the invite

Connect Webhook → Google Calendar. **Activate** the workflow.

## Then
Give me the webhook **Production URL** and I'll paste it into the portal (`WEBHOOK_URL`). After that, adding a meeting emails the client a real Google Calendar invite.

> Note: the webhook URL sits in the portal's client-side code, so treat it as semi-public. If you want it locked down later, we can add a shared-secret header the workflow checks.
