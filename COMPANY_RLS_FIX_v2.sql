-- Fix Row Level Security policies for companies table
-- Updated to work with TEXT id columns instead of UUID

-- First, drop any existing policies
DROP POLICY IF EXISTS "Users can create companies" ON public.companies;
DROP POLICY IF EXISTS "Users can read their company" ON public.companies;
DROP POLICY IF EXISTS "Users can update their company" ON public.companies;
DROP POLICY IF EXISTS "Users can delete their company" ON public.companies;

-- Enable RLS on the companies table
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

-- INSERT Policy: Allow any authenticated user to create a company
-- This is necessary because when creating a new company, the user doesn't have a company_id yet
CREATE POLICY "Users can create companies"
ON public.companies FOR INSERT
TO authenticated
WITH CHECK (true);

-- SELECT Policy: Users can read their own company
-- Updated to work with TEXT id columns by casting both sides to TEXT
CREATE POLICY "Users can read their company"
ON public.companies FOR SELECT
TO authenticated
USING (
    id IN (
        SELECT company_id FROM public.users WHERE id::TEXT = (auth.uid())::TEXT
    )
);

-- UPDATE Policy: Users can update their own company
-- Updated to work with TEXT id columns by casting both sides to TEXT
CREATE POLICY "Users can update their company"
ON public.companies FOR UPDATE
TO authenticated
USING (
    id IN (
        SELECT company_id FROM public.users WHERE id::TEXT = (auth.uid())::TEXT
    )
)
WITH CHECK (
    id IN (
        SELECT company_id FROM public.users WHERE id::TEXT = (auth.uid())::TEXT
    )
);

-- DELETE Policy: Users can delete their own company (optional)
CREATE POLICY "Users can delete their company"
ON public.companies FOR DELETE
TO authenticated
USING (
    id IN (
        SELECT company_id FROM public.users WHERE id::TEXT = (auth.uid())::TEXT
    )
);

-- Verify the policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'companies';
