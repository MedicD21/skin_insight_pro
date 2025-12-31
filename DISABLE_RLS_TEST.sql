-- Temporarily disable RLS to test if that's the issue
-- DO NOT USE THIS IN PRODUCTION - this is just for testing

ALTER TABLE public.companies DISABLE ROW LEVEL SECURITY;

-- After testing, you should re-enable it with proper policies
