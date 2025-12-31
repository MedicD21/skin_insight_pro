-- Supabase Migration Script for Company Features
-- Safe to run multiple times (idempotent)

-- ============================================
-- 1. Add columns to users table
-- ============================================
DO $$
BEGIN
    -- Add company_id column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='users' AND column_name='company_id'
    ) THEN
        ALTER TABLE users ADD COLUMN company_id TEXT;
    END IF;

    -- Add first_name column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='users' AND column_name='first_name'
    ) THEN
        ALTER TABLE users ADD COLUMN first_name TEXT;
    END IF;

    -- Add last_name column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='users' AND column_name='last_name'
    ) THEN
        ALTER TABLE users ADD COLUMN last_name TEXT;
    END IF;

    -- Add phone_number column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='users' AND column_name='phone_number'
    ) THEN
        ALTER TABLE users ADD COLUMN phone_number TEXT;
    END IF;

    -- Add profile_image_url column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='users' AND column_name='profile_image_url'
    ) THEN
        ALTER TABLE users ADD COLUMN profile_image_url TEXT;
    END IF;

    -- Add role column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='users' AND column_name='role'
    ) THEN
        ALTER TABLE users ADD COLUMN role TEXT;
    END IF;
END $$;

-- ============================================
-- 2. Add columns to clients table
-- ============================================
DO $$
BEGIN
    -- Add company_id column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='clients' AND column_name='company_id'
    ) THEN
        ALTER TABLE clients ADD COLUMN company_id TEXT;
    END IF;

    -- Add profile_image_url column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='clients' AND column_name='profile_image_url'
    ) THEN
        ALTER TABLE clients ADD COLUMN profile_image_url TEXT;
    END IF;
END $$;

-- ============================================
-- 3. Create companies table
-- ============================================
CREATE TABLE IF NOT EXISTS companies (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    logo_url TEXT,
    website TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 4. Create indexes for performance
-- ============================================
-- Index on users.company_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_company_id ON users(company_id);

-- Index on clients.company_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_clients_company_id ON clients(company_id);

-- ============================================
-- 5. Add foreign key constraints (optional)
-- ============================================
-- Note: Only add if you want to enforce referential integrity
-- Uncomment the following if desired:

/*
DO $$
BEGIN
    -- Add foreign key from users to companies
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_users_company'
    ) THEN
        ALTER TABLE users
        ADD CONSTRAINT fk_users_company
        FOREIGN KEY (company_id)
        REFERENCES companies(id)
        ON DELETE SET NULL;
    END IF;

    -- Add foreign key from clients to companies
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_clients_company'
    ) THEN
        ALTER TABLE clients
        ADD CONSTRAINT fk_clients_company
        FOREIGN KEY (company_id)
        REFERENCES companies(id)
        ON DELETE SET NULL;
    END IF;
END $$;
*/

-- ============================================
-- 6. Enable Row Level Security (RLS) for companies
-- ============================================
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (safe to fail if they don't exist)
DROP POLICY IF EXISTS "Users can read their company" ON companies;
DROP POLICY IF EXISTS "Users can create companies" ON companies;
DROP POLICY IF EXISTS "Users can update their company" ON companies;

-- Policy: Users can read companies they belong to
CREATE POLICY "Users can read their company"
ON companies FOR SELECT
USING (
    id IN (
        SELECT company_id FROM users WHERE id::UUID = auth.uid()
    )
);

-- Policy: Users can insert companies (anyone can create)
CREATE POLICY "Users can create companies"
ON companies FOR INSERT
WITH CHECK (true);

-- Policy: Users in a company can update their company
CREATE POLICY "Users can update their company"
ON companies FOR UPDATE
USING (
    id IN (
        SELECT company_id FROM users WHERE id::UUID = auth.uid()
    )
);

-- ============================================
-- 7. Update RLS policies for company-wide client access
-- ============================================
-- Drop existing client policies if needed and recreate
-- Note: Adjust these based on your existing RLS setup

/*
-- Example: Allow users to see all clients in their company
DROP POLICY IF EXISTS "Users can read clients in their company" ON clients;

CREATE POLICY "Users can read clients in their company"
ON clients FOR SELECT
USING (
    company_id IN (
        SELECT company_id FROM users WHERE id::UUID = auth.uid()
    )
    OR
    user_id::UUID = auth.uid()
);

-- Allow users to create clients for their company
DROP POLICY IF EXISTS "Users can create clients" ON clients;

CREATE POLICY "Users can create clients"
ON clients FOR INSERT
WITH CHECK (
    company_id IN (
        SELECT company_id FROM users WHERE id::UUID = auth.uid()
    )
    OR
    user_id::UUID = auth.uid()
);
*/

-- ============================================
-- Migration complete!
-- ============================================
-- Run this script in your Supabase SQL Editor
-- It's safe to run multiple times
