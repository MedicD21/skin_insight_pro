-- Add ai_provider column to skin_analyses table
-- This tracks which AI provider was used for each analysis
-- Run this in Supabase Dashboard > SQL Editor

-- Add the column
ALTER TABLE skin_analyses
ADD COLUMN IF NOT EXISTS ai_provider TEXT DEFAULT 'appleVision';

-- Add a comment
COMMENT ON COLUMN skin_analyses.ai_provider IS 'AI provider used for analysis: appleVision (free) or claude (premium)';

-- Create an index for faster queries
CREATE INDEX IF NOT EXISTS idx_skin_analyses_ai_provider_created
ON skin_analyses(ai_provider, created_at);

-- Verify the change
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'skin_analyses'
  AND column_name = 'ai_provider';
