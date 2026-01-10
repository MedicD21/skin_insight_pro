-- =============================================================================
-- IAP (In-App Purchase) Setup for SkinInsightPro
-- =============================================================================
-- Run these SQL statements in Supabase Dashboard → SQL Editor
-- =============================================================================

-- Step 1: Create IAP Events Table
-- This table logs all in-app purchase events for auditing and reconciliation
CREATE TABLE IF NOT EXISTS iap_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('purchase', 'renewal', 'cancel', 'refund', 'restore')),
    product_id TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    original_transaction_id TEXT,
    purchase_date TIMESTAMPTZ,
    expiration_date TIMESTAMPTZ,
    cancellation_date TIMESTAMPTZ,
    amount DECIMAL(10, 2),
    currency TEXT DEFAULT 'USD',
    raw_receipt JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_iap_events_company ON iap_events(company_id);
CREATE INDEX IF NOT EXISTS idx_iap_events_user ON iap_events(user_id);
CREATE INDEX IF NOT EXISTS idx_iap_events_transaction ON iap_events(transaction_id);
CREATE INDEX IF NOT EXISTS idx_iap_events_type ON iap_events(event_type);
CREATE INDEX IF NOT EXISTS idx_iap_events_created ON iap_events(created_at DESC);

-- Add comment for documentation
COMMENT ON TABLE iap_events IS 'Logs all in-app purchase events (purchase, renewal, cancel, refund, restore) for billing reconciliation';

-- =============================================================================

-- Step 2: Add IAP Columns to company_plans Table
-- These columns link company plans to Apple IAP transactions
ALTER TABLE company_plans
ADD COLUMN IF NOT EXISTS iap_product_id TEXT,
ADD COLUMN IF NOT EXISTS iap_transaction_id TEXT,
ADD COLUMN IF NOT EXISTS iap_original_transaction_id TEXT,
ADD COLUMN IF NOT EXISTS iap_receipt_data TEXT;

-- Create index for faster transaction lookups
CREATE INDEX IF NOT EXISTS idx_company_plans_iap_transaction
ON company_plans(iap_transaction_id);

-- Add comments for documentation
COMMENT ON COLUMN company_plans.iap_product_id IS 'Apple IAP product identifier (e.g., skininsight.low.monthly)';
COMMENT ON COLUMN company_plans.iap_transaction_id IS 'Current Apple transaction ID';
COMMENT ON COLUMN company_plans.iap_original_transaction_id IS 'Original Apple transaction ID (for subscription tracking)';
COMMENT ON COLUMN company_plans.iap_receipt_data IS 'Encrypted Apple receipt data for verification';

-- =============================================================================

-- Step 3: Verify the Setup
-- Run these queries to confirm everything is created correctly

-- Check iap_events table
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'iap_events'
ORDER BY ordinal_position;

-- Check company_plans IAP columns
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'company_plans'
    AND column_name LIKE 'iap_%'
ORDER BY ordinal_position;

-- Check indexes
SELECT
    indexname,
    tablename
FROM pg_indexes
WHERE tablename IN ('iap_events', 'company_plans')
    AND indexname LIKE '%iap%'
ORDER BY tablename, indexname;

-- =============================================================================

-- Step 4 (OPTIONAL): Enable Row Level Security (RLS)
-- Uncomment if you want to add RLS policies for IAP data

-- ALTER TABLE iap_events ENABLE ROW LEVEL SECURITY;

-- -- Users can only view their company's IAP events
-- CREATE POLICY "Users can view own company IAP events"
-- ON iap_events
-- FOR SELECT
-- USING (
--     company_id IN (
--         SELECT company_id FROM users WHERE id = auth.uid()
--     )
-- );

-- -- Only authenticated users can insert IAP events
-- CREATE POLICY "Authenticated users can insert IAP events"
-- ON iap_events
-- FOR INSERT
-- WITH CHECK (
--     user_id = auth.uid()
-- );

-- -- Admins can view all IAP events
-- CREATE POLICY "Admins can view all IAP events"
-- ON iap_events
-- FOR SELECT
-- USING (
--     EXISTS (
--         SELECT 1 FROM users
--         WHERE id = auth.uid()
--         AND is_admin = true
--     )
-- );

-- =============================================================================
