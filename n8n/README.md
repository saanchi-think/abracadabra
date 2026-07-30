# n8n workflows (exports)

These are exports of the n8n workflows that power the portal's file features, kept here so the repo stays the source of truth. The live copies run on `https://n8n.srv1000837.hstgr.cloud`.

## How client files flow into the portal

```
Client's Google Drive folder
└── External/          ← ONLY this is visible in the portal
│     proposals, contracts, client-safe meeting summaries, media
└── Internal/          ← never shown to the client
      raw meeting notes, drafts, internal docs
```

1. Staff link a client's Drive folder in **admin.html** (Add-client form, or the "Set" control on an existing client row). This saves `drive_folder_id` on the client's row in Supabase.
2. **`client-folder-provisioning.json`** (runs every 30 min, or on demand via `POST /webhook/provision-client-folders`) creates the `Internal`/`External` subfolders for any linked client that's missing them. Idempotent — safe to run any time.
3. Staff put client-facing files in `External` (proposals, contracts, media). Internal material stays in `Internal` or the folder root — neither is ever shown.
4. When a client opens **Proposals & Media** or **Contract** in the portal, index.html POSTs their `drive_folder_id` to `POST /webhook/portal-drive-files` — **`think-portal-drive-files.json`** looks up the `External` subfolder inside it and returns only those files. The Contract tab is the same list filtered by filename (contract/agreement/SOW/NDA…).

## Re-importing

n8n → Workflows → ⋯ → Import from File. Re-attach the Google Drive credential on any node showing a warning, then Activate. The Supabase key inside is the public (anon/publishable) key — same one embedded in the portal HTML.
