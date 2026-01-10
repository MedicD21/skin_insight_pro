-- Add trending metrics columns to skin_analyses table
-- These columns store numeric scores (0-10) for each skin metric to enable trending analysis

-- Note: The analysis_results JSONB column already exists and contains AnalysisData
-- We're adding these denormalized columns for easier querying and trending

ALTER TABLE skin_analyses
ADD COLUMN IF NOT EXISTS oiliness_score DECIMAL(3,1) DEFAULT 0 CHECK (oiliness_score >= 0 AND oiliness_score <= 10),
ADD COLUMN IF NOT EXISTS texture_score DECIMAL(3,1) DEFAULT 0 CHECK (texture_score >= 0 AND texture_score <= 10),
ADD COLUMN IF NOT EXISTS pores_score DECIMAL(3,1) DEFAULT 0 CHECK (pores_score >= 0 AND pores_score <= 10),
ADD COLUMN IF NOT EXISTS wrinkles_score DECIMAL(3,1) DEFAULT 0 CHECK (wrinkles_score >= 0 AND wrinkles_score <= 10),
ADD COLUMN IF NOT EXISTS redness_score DECIMAL(3,1) DEFAULT 0 CHECK (redness_score >= 0 AND redness_score <= 10),
ADD COLUMN IF NOT EXISTS dark_spots_score DECIMAL(3,1) DEFAULT 0 CHECK (dark_spots_score >= 0 AND dark_spots_score <= 10),
ADD COLUMN IF NOT EXISTS acne_score DECIMAL(3,1) DEFAULT 0 CHECK (acne_score >= 0 AND acne_score <= 10),
ADD COLUMN IF NOT EXISTS sensitivity_score DECIMAL(3,1) DEFAULT 0 CHECK (sensitivity_score >= 0 AND sensitivity_score <= 10);

-- Add comments for documentation
COMMENT ON COLUMN skin_analyses.oiliness_score IS 'Oiliness/sebum level (0=very dry, 10=very oily)';
COMMENT ON COLUMN skin_analyses.texture_score IS 'Skin texture quality (0=very rough, 10=very smooth)';
COMMENT ON COLUMN skin_analyses.pores_score IS 'Pore visibility (0=invisible, 10=very enlarged)';
COMMENT ON COLUMN skin_analyses.wrinkles_score IS 'Wrinkle/fine line severity (0=none, 10=severe)';
COMMENT ON COLUMN skin_analyses.redness_score IS 'Redness/inflammation level (0=none, 10=severe)';
COMMENT ON COLUMN skin_analyses.dark_spots_score IS 'Hyperpigmentation severity (0=none, 10=severe)';
COMMENT ON COLUMN skin_analyses.acne_score IS 'Acne/breakout severity (0=none, 10=severe)';
COMMENT ON COLUMN skin_analyses.sensitivity_score IS 'Skin sensitivity level (0=not sensitive, 10=very sensitive)';

-- Create index for faster trending queries
CREATE INDEX IF NOT EXISTS idx_skin_analysis_client_date ON skin_analyses(client_id, created_at DESC);

-- Optional: Backfill existing data from concerns array (rough estimates)
-- This gives reasonable values for existing analyses so trends show something
UPDATE skin_analyses
SET
    redness_score = CASE
        WHEN analysis_results->>'concerns' LIKE '%Redness%' THEN 6.0
        ELSE 2.0
    END,
    dark_spots_score = CASE
        WHEN analysis_results->>'concerns' LIKE '%Dark Spots%' OR analysis_results->>'concerns' LIKE '%Dark spots%' THEN 6.0
        ELSE 2.0
    END,
    acne_score = CASE
        WHEN analysis_results->>'concerns' LIKE '%Acne%' THEN 6.0
        ELSE 2.0
    END,
    wrinkles_score = CASE
        WHEN analysis_results->>'concerns' LIKE '%Fine Lines%' OR analysis_results->>'concerns' LIKE '%Fine lines%' THEN 6.0
        WHEN analysis_results->>'concerns' LIKE '%Aging%' THEN 5.0
        ELSE 2.0
    END,
    pores_score = CASE
        WHEN analysis_results->>'concerns' LIKE '%Enlarged pores%' OR analysis_results->>'concerns' LIKE '%Pores%' THEN 6.0
        WHEN analysis_results->>'pore_condition' = 'Enlarged' THEN 7.0
        WHEN analysis_results->>'pore_condition' = 'Normal' THEN 3.0
        ELSE 4.0
    END,
    texture_score = CASE
        WHEN analysis_results->>'concerns' LIKE '%Uneven texture%' THEN 4.0
        ELSE 7.0
    END,
    oiliness_score = CASE
        WHEN analysis_results->>'concerns' LIKE '%Excess oil%' OR analysis_results->>'concerns' LIKE '%Oiliness%' THEN 7.0
        WHEN analysis_results->>'skin_type' = 'Oily' THEN 7.5
        WHEN analysis_results->>'skin_type' = 'Dry' THEN 2.5
        WHEN analysis_results->>'skin_type' = 'Combination' THEN 5.5
        ELSE 5.0
    END,
    sensitivity_score = CASE
        WHEN analysis_results->>'sensitivity' = 'High' THEN 8.0
        WHEN analysis_results->>'sensitivity' = 'Moderate' THEN 5.0
        WHEN analysis_results->>'sensitivity' = 'Low' THEN 2.0
        ELSE 3.0
    END
WHERE oiliness_score = 0; -- Only update records that haven't been set yet

-- Verify the update
SELECT
    COUNT(*) as total_analyses,
    AVG(oiliness_score) as avg_oiliness,
    AVG(texture_score) as avg_texture,
    AVG(pores_score) as avg_pores,
    AVG(wrinkles_score) as avg_wrinkles,
    AVG(redness_score) as avg_redness,
    AVG(dark_spots_score) as avg_dark_spots,
    AVG(acne_score) as avg_acne,
    AVG(sensitivity_score) as avg_sensitivity
FROM skin_analyses;
