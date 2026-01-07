# Claude Usage Enforcement (Supabase Edge Function)

This document explains how to deploy and wire the Claude usage enforcement function.

## 1) Create the Edge Function

This repo includes the function at:

`supabase/functions/claude-analyze/index.ts`

It will:
- Validate the user JWT.
- Check usage limits via `record_claude_usage`.
- Call Claude if allowed.

## 2) Set Function Secrets

In Supabase → Project Settings → Functions → Secrets:

- `ANTHROPIC_API_KEY`

Note: `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically by
Supabase for Edge Functions and cannot be added in the Secrets UI (names with
`SUPABASE_` are reserved).

## 3) Deploy

```sh
supabase functions deploy claude-analyze --project-ref meqrnevrimzvvhmopxrq
```

## 4) App Call

The app should call:

`POST https://<project_ref>.supabase.co/functions/v1/claude-analyze`

Headers:
- `Authorization: Bearer <user_access_token>`
- `apikey: <supabase_anon_key>`
- `Content-Type: application/json`

Body:
```json
{
  "image_base64": "<base64>",
  "prompt": "<prompt>",
  "model": "claude-sonnet-4-5-20250929"
}
```

If the user or company is over their cap, the function returns HTTP `402` with usage details.

## 5) Rollback

If you want to revert to direct Claude calls, change the app to call Claude directly again.
