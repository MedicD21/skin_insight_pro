-- Team Members Setup - Simple Company Code Approach
-- This allows users to join a company by entering the company ID

-- 1. Update RLS policies for users table to allow team members to see each other
-- First, drop existing user SELECT policies if any
DROP POLICY IF EXISTS "Users can view team members in their company" ON public.users;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;

-- Allow users to view themselves and team members in their company
CREATE POLICY "Users can view team members"
ON public.users FOR SELECT
USING (
    -- User can see themselves
    id::TEXT = (auth.uid())::TEXT
    OR
    -- User can see others in their company
    (company_id IS NOT NULL AND company_id IN (
        SELECT company_id FROM public.users WHERE id::TEXT = (auth.uid())::TEXT
    ))
);

-- 2. Allow users to update their own company_id (for joining a company)
DROP POLICY IF EXISTS "Users can update their profile" ON public.users;

CREATE POLICY "Users can update their profile"
ON public.users FOR UPDATE
USING (id::TEXT = (auth.uid())::TEXT)
WITH CHECK (id::TEXT = (auth.uid())::TEXT);

-- 3. Verify the policies
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename = 'users'
ORDER BY cmd, policyname;
