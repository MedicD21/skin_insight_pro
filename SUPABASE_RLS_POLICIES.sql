-- ========================================
-- Supabase RLS Policies for Skin Insight Pro
-- ========================================
-- Run this script in Supabase SQL Editor
-- This will set up secure Row Level Security policies
-- ========================================

-- ----------------------------------------
-- Step 1: Drop All Old Policies
-- ----------------------------------------

-- Users table
DROP POLICY IF EXISTS "Users can view own data" ON users;
DROP POLICY IF EXISTS "Anyone can create users" ON users;
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;

-- Clients table
DROP POLICY IF EXISTS "Users can view own clients" ON clients;
DROP POLICY IF EXISTS "Users can insert clients" ON clients;
DROP POLICY IF EXISTS "Users can update clients" ON clients;
DROP POLICY IF EXISTS "Users can insert own clients" ON clients;
DROP POLICY IF EXISTS "Users can update own clients" ON clients;
DROP POLICY IF EXISTS "Users can delete own clients" ON clients;

-- Skin analyses table
DROP POLICY IF EXISTS "Users can view analyses" ON skin_analyses;
DROP POLICY IF EXISTS "Users can insert analyses" ON skin_analyses;
DROP POLICY IF EXISTS "Users can view own analyses" ON skin_analyses;
DROP POLICY IF EXISTS "Users can insert own analyses" ON skin_analyses;
DROP POLICY IF EXISTS "Users can update own analyses" ON skin_analyses;
DROP POLICY IF EXISTS "Users can delete own analyses" ON skin_analyses;

-- Products table
DROP POLICY IF EXISTS "Users can view products" ON products;
DROP POLICY IF EXISTS "Users can insert products" ON products;
DROP POLICY IF EXISTS "Users can update products" ON products;
DROP POLICY IF EXISTS "Users can view own products" ON products;
DROP POLICY IF EXISTS "Users can insert own products" ON products;
DROP POLICY IF EXISTS "Users can update own products" ON products;
DROP POLICY IF EXISTS "Users can delete own products" ON products;

-- AI Rules table
DROP POLICY IF EXISTS "Users can view rules" ON ai_rules;
DROP POLICY IF EXISTS "Users can insert rules" ON ai_rules;
DROP POLICY IF EXISTS "Users can update rules" ON ai_rules;
DROP POLICY IF EXISTS "Users can view own rules" ON ai_rules;
DROP POLICY IF EXISTS "Users can insert own rules" ON ai_rules;
DROP POLICY IF EXISTS "Users can update own rules" ON ai_rules;
DROP POLICY IF EXISTS "Users can delete own rules" ON ai_rules;

-- ----------------------------------------
-- Step 2: Create New Secure Policies
-- ----------------------------------------

-- ========================================
-- USERS TABLE POLICIES
-- ========================================

-- Users can view their own profile
CREATE POLICY "Users can view own profile" ON users
FOR SELECT
TO authenticated
USING (id = auth.uid());

-- Users can insert their own profile (needed after signup)
CREATE POLICY "Users can insert own profile" ON users
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON users
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- ========================================
-- CLIENTS TABLE POLICIES
-- ========================================

-- Users can view their own clients
CREATE POLICY "Users can view own clients" ON clients
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Users can insert their own clients
CREATE POLICY "Users can insert own clients" ON clients
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Users can update their own clients
CREATE POLICY "Users can update own clients" ON clients
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Users can delete their own clients
CREATE POLICY "Users can delete own clients" ON clients
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ========================================
-- SKIN ANALYSES TABLE POLICIES
-- ========================================

-- Users can view their own analyses
CREATE POLICY "Users can view own analyses" ON skin_analyses
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Users can insert their own analyses
CREATE POLICY "Users can insert own analyses" ON skin_analyses
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Users can update their own analyses
CREATE POLICY "Users can update own analyses" ON skin_analyses
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Users can delete their own analyses
CREATE POLICY "Users can delete own analyses" ON skin_analyses
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ========================================
-- PRODUCTS TABLE POLICIES
-- ========================================

-- All users can view products
CREATE POLICY "Users can view own products" ON products
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Users can insert their own products
CREATE POLICY "Users can insert own products" ON products
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Users can update their own products
CREATE POLICY "Users can update own products" ON products
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Users can delete their own products
CREATE POLICY "Users can delete own products" ON products
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ========================================
-- AI RULES TABLE POLICIES
-- ========================================

-- Users can view their own rules
CREATE POLICY "Users can view own rules" ON ai_rules
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Users can insert their own rules
CREATE POLICY "Users can insert own rules" ON ai_rules
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Users can update their own rules
CREATE POLICY "Users can update own rules" ON ai_rules
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Users can delete their own rules
CREATE POLICY "Users can delete own rules" ON ai_rules
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ========================================
-- VERIFICATION
-- ========================================

-- Run this to verify all policies were created:
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ========================================
-- DONE!
-- ========================================
-- All RLS policies have been set up securely.
-- Users can now only access their own data.
-- ========================================
