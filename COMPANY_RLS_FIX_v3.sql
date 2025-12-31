-- Fix Row Level Security policies for companies table
-- Simplified approach that works with both anon and authenticated roles

-- First, drop any existing policies
DROP POLICY IF EXISTS "Users can create companies" ON public.companies;
DROP POLICY IF EXISTS "Users can read their company" ON public.companies;
DROP POLICY IF EXISTS "Users can update their company" ON public.companies;
DROP POLICY IF EXISTS "Users can delete their company" ON public.companies;

-- Enable RLS on the companies table
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

-- INSERT Policy: Allow anyone with a valid JWT to create a company
-- Using PUBLIC means both anon and authenticated roles can access
CREATE POLICY "Users can create companies"
ON public.companies FOR INSERT
WITH CHECK (true);

-- SELECT Policy: Users can read their own company
-- Using PUBLIC to work with both anon and authenticated roles
CREATE POLICY "Users can read their company"
ON public.companies FOR SELECT
USING (
    id IN (
        SELECT company_id FROM public.users WHERE id::TEXT = (auth.uid())::TEXT
    )
);

-- UPDATE Policy: Users can update their own company
-- Using PUBLIC to work with both anon and authenticated roles
CREATE POLICY "Users can update their company"
ON public.companies FOR UPDATE
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

-- DELETE Policy: Users can delete their own company
-- Using PUBLIC to work with both anon and authenticated roles
CREATE POLICY "Users can delete their company"
ON public.companies FOR DELETE
USING (
    id IN (
        SELECT company_id FROM public.users WHERE id::TEXT = (auth.uid())::TEXT
    )
);

-- Verify the policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'companies';
