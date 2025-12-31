-- Debug script to check RLS policies and authentication

-- 1. Check current user authentication
SELECT
    current_user AS postgres_user,
    current_setting('request.jwt.claims', true) AS jwt_claims,
    auth.uid() AS auth_uid,
    auth.role() AS auth_role;

-- 2. Check all policies on companies table
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'companies';

-- 3. Check if RLS is enabled
SELECT
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'companies';

-- 4. Try a simple INSERT test (will fail if RLS blocks it)
-- This helps us see what's happening
INSERT INTO companies (id, name, email, phone, address, website)
VALUES ('test-company-id', 'Test Company', 'test@test.com', '1234567890', 'Test Address', 'test.com')
RETURNING *;
