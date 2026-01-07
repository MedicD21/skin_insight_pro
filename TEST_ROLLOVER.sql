-- =============================================================================
-- TEST: Monthly Plan Rollover
-- =============================================================================
-- This script helps you test the plan rollover Edge Function before deploying
-- Run these steps in order in the Supabase SQL Editor
-- =============================================================================

-- STEP 1: Create a test plan that expires in 2 minutes
-- -----------------------------------------------------------------------------
-- This creates a plan that will be eligible for rollover very soon

INSERT INTO company_plans (
    company_id,
    tier,
    started_at,
    ends_at,
    status,
    created_at,
    updated_at
)
SELECT
    id AS company_id,
    'professional' AS tier,
    NOW() - INTERVAL '1 month' AS started_at,
    NOW() + INTERVAL '2 minutes' AS ends_at,
    'active' AS status,
    NOW() AS created_at,
    NOW() AS updated_at
FROM companies
LIMIT 1
RETURNING
    id,
    company_id,
    tier,
    started_at,
    ends_at,
    status;

-- Expected output: A new plan record with ends_at ~2 minutes in the future
-- Copy the 'id' value - you'll need it to verify the rollover


-- STEP 2: Wait 3 minutes, then check if plan needs rollover
-- -----------------------------------------------------------------------------
-- Run this query after waiting 3 minutes

SELECT
    id,
    company_id,
    tier,
    started_at,
    ends_at,
    status,
    ends_at < NOW() AS is_expired,
    NOW() - ends_at AS time_since_expiry
FROM company_plans
WHERE id = '<PASTE_ID_FROM_STEP_1>'
ORDER BY created_at DESC;

-- Expected: is_expired should be TRUE


-- STEP 3: Manually trigger the rollover function
-- -----------------------------------------------------------------------------
-- After deploying the Edge Function, run this curl command in your terminal:
/*

curl -X POST \
  'https://[your-project-ref].supabase.co/functions/v1/rollover-plans' \
  -H 'Authorization: Bearer [YOUR_CRON_SECRET]' \
  -H 'Content-Type: application/json'

Expected response:
{
  "success": true,
  "rolledOverCount": 1,
  "expiredCount": 0,
  "errors": [],
  "timestamp": "2026-01-07T..."
}

*/


-- STEP 4: Verify the plan was rolled over
-- -----------------------------------------------------------------------------
-- Check that the dates were updated correctly

SELECT
    id,
    company_id,
    tier,
    started_at,
    ends_at,
    status,
    updated_at,
    ends_at - started_at AS period_length
FROM company_plans
WHERE id = '<PASTE_ID_FROM_STEP_1>';

-- Expected results:
-- 1. started_at should equal the OLD ends_at
-- 2. ends_at should be ~1 month after started_at
-- 3. status should still be 'active'
-- 4. updated_at should be very recent (when rollover ran)
-- 5. period_length should be ~30 days


-- STEP 5: Verify usage count reset
-- -----------------------------------------------------------------------------
-- Check that usage tracking recognizes the new billing period

SELECT * FROM get_company_usage(
    (SELECT company_id FROM company_plans WHERE id = '<PASTE_ID_FROM_STEP_1>')
);

-- Expected:
-- - units_used should be 0 (new period, no usage yet)
-- - current_period_start should match the new started_at
-- - current_period_end should match the new ends_at


-- CLEANUP: Remove the test plan
-- -----------------------------------------------------------------------------
-- After verifying everything works, delete the test plan

DELETE FROM company_plans
WHERE id = '<PASTE_ID_FROM_STEP_1>'
RETURNING *;

-- =============================================================================
-- TEST COMPLETE
-- =============================================================================

-- If all steps passed:
-- ✅ Edge Function is working correctly
-- ✅ Plan rollover logic is correct
-- ✅ Usage tracking respects new billing periods
-- ✅ Ready to enable automated cron trigger

-- =============================================================================
-- BONUS: Test Expired Plan Handling
-- =============================================================================

-- Create an inactive plan that should be marked as expired
INSERT INTO company_plans (
    company_id,
    tier,
    started_at,
    ends_at,
    status,
    created_at,
    updated_at
)
SELECT
    id AS company_id,
    'starter' AS tier,
    NOW() - INTERVAL '2 months' AS started_at,
    NOW() - INTERVAL '1 month' AS ends_at,  -- Already expired
    'inactive' AS status,
    NOW() AS created_at,
    NOW() AS updated_at
FROM companies
LIMIT 1
RETURNING
    id,
    company_id,
    status,
    ends_at;

-- Copy the 'id' value

-- Trigger rollover function again (same curl command as STEP 3)

-- Check if status changed to 'expired'
SELECT
    id,
    company_id,
    tier,
    status,
    ends_at,
    updated_at
FROM company_plans
WHERE id = '<PASTE_ID_FROM_BONUS_TEST>'
ORDER BY created_at DESC;

-- Expected: status should be 'expired' (changed from 'inactive')

-- Cleanup
DELETE FROM company_plans WHERE id = '<PASTE_ID_FROM_BONUS_TEST>';

-- =============================================================================
