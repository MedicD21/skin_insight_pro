-- Grant platform admin privileges to existing users (for testing)
-- Run this in Supabase Dashboard > SQL Editor
--
-- NOTE: New users who create companies will automatically get both
-- is_admin and is_company_admin set to true via the app.
-- This script is only needed for existing users who created companies
-- before the auto-grant feature was implemented.

UPDATE users
SET is_admin = true
WHERE email IN ('bob@bob.com', 'kyle@kyle.com');

-- Verify the update
SELECT
    id,
    email,
    first_name,
    last_name,
    is_admin,
    is_company_admin,
    company_id
FROM users
WHERE email IN ('bob@bob.com', 'kyle@kyle.com')
ORDER BY email;
