-- Migration: Add wrinkle_relaxers_date field to clients table
-- Purpose: Track wrinkle relaxer (Botox, Dysport, etc.) administration dates for comprehensive injectables history
-- Date: 2026-01-12

-- Add wrinkle_relaxers_date column
ALTER TABLE clients
ADD COLUMN IF NOT EXISTS wrinkle_relaxers_date TEXT;

-- Add comment to document the column
COMMENT ON COLUMN clients.wrinkle_relaxers_date IS 'ISO8601 timestamp of last wrinkle relaxer treatment (e.g., Botox, Dysport, Xeomin). Used for tracking injectables history and informing skin analysis recommendations.';

-- Verify the change
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'clients'
AND column_name = 'wrinkle_relaxers_date';
