-- Server-Side Validation for Claude Vision AI Usage
-- This function enforces subscription requirements and monthly usage caps
-- Run this in Supabase Dashboard > SQL Editor

-- Drop any existing versions of the function first
DROP FUNCTION IF EXISTS record_claude_usage(TEXT, TEXT);
DROP FUNCTION IF EXISTS record_claude_usage;

-- Create function to check and record Claude usage
CREATE OR REPLACE FUNCTION record_claude_usage(
    p_company_id TEXT,
    p_user_id TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_plan_name TEXT;
    v_monthly_cap INT;
    v_current_count INT;
    v_result JSON;
    v_is_god_mode BOOLEAN;
BEGIN
    -- 0. Check if user has GOD mode enabled
    SELECT god_mode INTO v_is_god_mode
    FROM users
    WHERE id::text = p_user_id;

    -- GOD mode users bypass all checks
    IF v_is_god_mode = true THEN
        v_result := json_build_object(
            'allowed', true,
            'current_usage', 0,
            'monthly_cap', 999999,
            'tier', 'GOD MODE',
            'remaining', 999999
        );
        RETURN v_result;
    END IF;

    -- 1. Check if company has an active subscription and get plan details
    SELECT
        p.name,
        p.monthly_company_cap
    INTO v_plan_name, v_monthly_cap
    FROM company_plans cp
    JOIN plans p ON p.id = cp.plan_id
    WHERE cp.company_id = p_company_id
      AND cp.status = 'active'
      AND (cp.ends_at IS NULL OR cp.ends_at > NOW())
    ORDER BY cp.ends_at DESC NULLS FIRST
    LIMIT 1;

    -- If no active subscription found, deny access
    IF v_plan_name IS NULL THEN
        v_result := json_build_object(
            'allowed', false,
            'reason', 'no_active_subscription',
            'message', 'No active subscription found for this company'
        );
        RETURN v_result;
    END IF;

    -- 2. Get current month's Claude usage count for this company
    SELECT COUNT(*)
    INTO v_current_count
    FROM skin_analyses
    WHERE client_id IN (
        SELECT id FROM clients WHERE company_id = p_company_id
    )
      AND ai_provider = 'claude'
      AND created_at >= date_trunc('month', NOW());

    -- 3. Check if usage would exceed the cap
    IF v_current_count >= v_monthly_cap THEN
        v_result := json_build_object(
            'allowed', false,
            'reason', 'monthly_limit_exceeded',
            'message', 'Monthly Claude Vision analysis limit reached',
            'current_usage', v_current_count,
            'monthly_cap', v_monthly_cap,
            'tier', v_plan_name
        );
        RETURN v_result;
    END IF;

    -- 4. Usage is allowed - return success
    v_result := json_build_object(
        'allowed', true,
        'current_usage', v_current_count,
        'monthly_cap', v_monthly_cap,
        'tier', v_plan_name,
        'remaining', v_monthly_cap - v_current_count
    );

    RETURN v_result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION record_claude_usage(TEXT, TEXT) TO authenticated;

-- Add comment
COMMENT ON FUNCTION record_claude_usage IS 'Validates subscription status and usage limits before allowing Claude Vision AI analysis';

-- Verify the function was created
SELECT
    p.proname as function_name,
    pg_catalog.pg_get_function_arguments(p.oid) as arguments,
    pg_catalog.pg_get_function_result(p.oid) as return_type
FROM pg_proc p
WHERE p.proname = 'record_claude_usage';

-- Test the function (replace with actual IDs from your database)
-- SELECT record_claude_usage('your-company-id', 'your-user-id');
