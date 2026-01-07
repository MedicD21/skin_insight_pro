# Monthly Plan Rollover - Edge Function Setup

This guide walks you through deploying the automated monthly plan rollover system using Supabase Edge Functions.

---

## 📋 What This Does

The `rollover-plans` Edge Function runs automatically on the 1st of each month at midnight (UTC) to:

1. **Rollover Active Plans**: Extends active plans to the next billing period
   - Updates `started_at` to previous `ends_at`
   - Sets new `ends_at` to 1 month later
   - Resets usage counters for the new period

2. **Expire Old Plans**: Marks inactive/cancelled plans as 'expired' if their end date has passed

3. **Logging**: Records rollover activity for monitoring and debugging

---

## 🚀 Deployment Steps

### Step 1: Deploy the Edge Function

From your project directory, run:

```bash
cd /Users/dustinschaaf/Desktop/skin_insight_pro

# Deploy the function to Supabase
supabase functions deploy rollover-plans
```

You should see output like:
```
Deploying function rollover-plans...
Function deployed successfully!
Function URL: https://[your-project-ref].supabase.co/functions/v1/rollover-plans
```

### Step 2: Set Up Cron Secret (Security)

To prevent unauthorized access, set a secret that only the cron trigger knows:

```bash
# Generate a random secret (or use your own)
CRON_SECRET=$(openssl rand -base64 32)

# Set the secret in Supabase
supabase secrets set CRON_SECRET="$CRON_SECRET"
```

**IMPORTANT**: Save this secret - you'll need it for the cron trigger setup.

### Step 3: Configure Cron Trigger

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Navigate to **Database** → **Extensions**
4. Enable the **pg_net** extension (if not already enabled)
5. Navigate to **Database** → **Cron Jobs**
6. Click **Create a new cron job**
7. Configure:
   - **Name**: `monthly-plan-rollover`
   - **Schedule**: `0 0 1 * *` (1st of month at midnight UTC)
   - **Command**:
   ```sql
   SELECT
     net.http_post(
       url:='https://[your-project-ref].supabase.co/functions/v1/rollover-plans',
       headers:=jsonb_build_object(
         'Content-Type', 'application/json',
         'Authorization', 'Bearer [YOUR_CRON_SECRET_HERE]'
       ),
       body:='{}'::jsonb
     ) as request_id;
   ```

**Replace**:
- `[your-project-ref]` with your actual Supabase project reference
- `[YOUR_CRON_SECRET_HERE]` with the CRON_SECRET you generated in Step 2

### Alternative: SQL-Based Cron Setup

If the UI method doesn't work, you can set up the cron job via SQL Editor:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the monthly rollover
SELECT cron.schedule(
  'monthly-plan-rollover',
  '0 0 1 * *', -- 1st of month at midnight UTC
  $$
  SELECT
    net.http_post(
      url:='https://[your-project-ref].supabase.co/functions/v1/rollover-plans',
      headers:=jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer [YOUR_CRON_SECRET_HERE]'
      ),
      body:='{}'::jsonb
    ) as request_id;
  $$
);
```

---

## ✅ Verify Deployment

### Test the Function Manually

You can test the function immediately (without waiting for the 1st of the month):

```bash
curl -X POST \
  'https://[your-project-ref].supabase.co/functions/v1/rollover-plans' \
  -H 'Authorization: Bearer [YOUR_CRON_SECRET]' \
  -H 'Content-Type: application/json'
```

Expected response:
```json
{
  "success": true,
  "rolledOverCount": 0,
  "expiredCount": 0,
  "errors": [],
  "timestamp": "2026-01-07T..."
}
```

### Check Cron Job Status

To verify the cron job is scheduled:

```sql
-- View all cron jobs
SELECT * FROM cron.job;

-- View cron job execution history
SELECT * FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'monthly-plan-rollover')
ORDER BY start_time DESC
LIMIT 10;
```

### Monitor Edge Function Logs

1. Go to Supabase Dashboard
2. Navigate to **Edge Functions** → **rollover-plans**
3. Click on **Logs** tab
4. You'll see execution logs showing:
   - Plans rolled over
   - Plans expired
   - Any errors

---

## 🔧 Configuration

### Change Rollover Schedule

To run at a different time, modify the cron expression:

| Expression | Meaning |
|------------|---------|
| `0 0 1 * *` | 1st of month, midnight UTC (default) |
| `0 3 1 * *` | 1st of month, 3 AM UTC |
| `0 0 15 * *` | 15th of month, midnight UTC |
| `0 0 * * 1` | Every Monday, midnight UTC |

Update via SQL:
```sql
-- Remove old schedule
SELECT cron.unschedule('monthly-plan-rollover');

-- Add new schedule
SELECT cron.schedule('monthly-plan-rollover', '0 3 1 * *', $$ ... $$);
```

### Disable Automatic Rollover

To temporarily pause or permanently remove:

```sql
-- Pause (can be re-enabled later)
SELECT cron.unschedule('monthly-plan-rollover');

-- Permanently remove cron job
DELETE FROM cron.job WHERE jobname = 'monthly-plan-rollover';
```

---

## 🧪 Testing Plan Rollover

### Create a Test Plan That Expires Soon

```sql
-- Create a test company plan that expires in 1 minute
INSERT INTO company_plans (
  company_id,
  tier,
  started_at,
  ends_at,
  status,
  created_at,
  updated_at
) VALUES (
  (SELECT id FROM companies LIMIT 1), -- Your company ID
  'professional',
  NOW() - INTERVAL '1 month',
  NOW() + INTERVAL '1 minute',
  'active',
  NOW(),
  NOW()
);

-- Wait 2 minutes, then manually trigger the function
-- (Use the curl command from "Test the Function Manually" above)

-- Check if the plan was rolled over
SELECT
  id,
  company_id,
  tier,
  started_at,
  ends_at,
  status,
  updated_at
FROM company_plans
ORDER BY updated_at DESC
LIMIT 1;
```

You should see:
- `started_at` = the old `ends_at`
- `ends_at` = 1 month after the old `ends_at`
- `status` = still 'active'

---

## 📊 Monitoring & Maintenance

### Monthly Checklist

After the 1st of each month:

1. Check Edge Function logs for any errors
2. Verify rolled-over plans:
   ```sql
   SELECT
     company_id,
     tier,
     started_at,
     ends_at,
     status
   FROM company_plans
   WHERE status = 'active'
   ORDER BY updated_at DESC;
   ```
3. Review usage has reset for new period:
   ```sql
   SELECT * FROM get_company_usage('[company_id]');
   ```

### Troubleshooting

**Issue**: Cron job not running

**Solution**:
1. Check cron job exists: `SELECT * FROM cron.job;`
2. Check for errors: `SELECT * FROM cron.job_run_details ORDER BY start_time DESC;`
3. Verify pg_cron extension enabled: `SELECT * FROM pg_extension WHERE extname = 'pg_cron';`

**Issue**: Function runs but plans don't rollover

**Solution**:
1. Check Edge Function logs in Supabase Dashboard
2. Verify service role key is set correctly
3. Test function manually with curl command
4. Check RLS policies aren't blocking the service role

**Issue**: "Unauthorized" error

**Solution**:
1. Verify CRON_SECRET is set: `supabase secrets list`
2. Check the secret matches in cron job configuration
3. Re-deploy function: `supabase functions deploy rollover-plans`

---

## 🎯 What Happens During Rollover

### Before Rollover (Dec 31, 11:59 PM)
```
Company Plan:
  started_at: 2025-12-01 00:00:00
  ends_at: 2026-01-01 00:00:00
  status: active

Usage Count: 150 analyses (within Dec 1 - Jan 1 period)
```

### After Rollover (Jan 1, 12:01 AM)
```
Company Plan:
  started_at: 2026-01-01 00:00:00  ← Updated
  ends_at: 2026-02-01 00:00:00     ← Updated
  status: active

Usage Count: 0 analyses (new period Jan 1 - Feb 1)
```

The `record_claude_usage()` function automatically counts usage within the new date range.

---

## 🔐 Security Notes

- ✅ Cron secret prevents unauthorized function calls
- ✅ Service role key bypasses RLS (needed for automated tasks)
- ✅ Function only accessible via cron trigger or manual testing with secret
- ✅ All actions logged in Edge Function logs
- ⚠️ Keep CRON_SECRET private - don't commit to git

---

## 📚 Related Documentation

- [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) - StoreKit 2 IAP setup
- [PRICING_TIERS.md](PRICING_TIERS.md) - Usage tier definitions
- [COMPLETED_FIXES.md](COMPLETED_FIXES.md) - Database fixes and setup

---

**Last Updated**: January 7, 2026
**Status**: Ready for deployment
