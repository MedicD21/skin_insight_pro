-- Migration: Add pregnancy and breastfeeding fields to clients table
-- Purpose: Track client pregnancy/breastfeeding status for product safety recommendations
-- Date: 2026-01-11

-- Add is_pregnant column
ALTER TABLE clients
ADD COLUMN IF NOT EXISTS is_pregnant BOOLEAN DEFAULT FALSE;

-- Add is_breastfeeding column
ALTER TABLE clients
ADD COLUMN IF NOT EXISTS is_breastfeeding BOOLEAN DEFAULT FALSE;

-- Add comments to document the columns
COMMENT ON COLUMN clients.is_pregnant IS 'Indicates if the client is currently pregnant. Used to flag contraindicated products containing salicylic acid or retinol.';
COMMENT ON COLUMN clients.is_breastfeeding IS 'Indicates if the client is currently breastfeeding. Used to flag contraindicated products containing salicylic acid or retinol.';

-- Verify the changes
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'clients'
AND column_name IN ('is_pregnant', 'is_breastfeeding');