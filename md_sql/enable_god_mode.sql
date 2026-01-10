-- Enable GOD Mode for Developer Account
-- Run this in Supabase Dashboard > SQL Editor
-- This script is IDEMPOTENT - safe to run multiple times

-- 1. Add god_mode column to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS god_mode BOOLEAN DEFAULT false;

-- 2. Add comment
COMMENT ON COLUMN users.god_mode IS 'GOD mode: Bypass all subscription checks and limits (for developer/owner only)';

-- 3. Create index for performance (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_users_god_mode ON users(god_mode) WHERE god_mode = true;

-- 4. Enable GOD mode for your account (dschaaf12@me.com)
UPDATE users
SET
    god_mode = true,
    is_company_admin = true  -- Also make company admin for testing purchases
WHERE email = 'dschaaf12@me.com';

-- 5. Verify the change
SELECT
    id,
    email,
    first_name,
    last_name,
    is_admin,
    is_company_admin,
    god_mode,
    company_id,
    company_name
FROM users
WHERE email = 'dschaaf12@me.com';

-- Expected result:
-- god_mode: true
-- is_company_admin: true
-- is_admin: true

-- 6. Check all GOD mode users (should only be you)
SELECT
    email,
    first_name,
    last_name,
    god_mode,
    is_admin
FROM users
WHERE god_mode = true;

-- 7. Now update the record_claude_usage function to respect GOD mode
-- Copy and run the contents of: create_claude_usage_tracking.sql
