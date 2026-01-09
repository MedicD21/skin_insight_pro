-- AI Rules Enhancement Migration
-- Adds support for general AI behavior settings in addition to conditional rules
-- Run this in Supabase Dashboard > SQL Editor

-- 1. Add new columns to ai_rules table
ALTER TABLE ai_rules
ADD COLUMN IF NOT EXISTS rule_type VARCHAR(20) DEFAULT 'condition' CHECK (rule_type IN ('condition', 'setting')),
ADD COLUMN IF NOT EXISTS setting_key VARCHAR(100),
ADD COLUMN IF NOT EXISTS setting_value TEXT;

-- 2. Create index for faster filtering by rule_type
CREATE INDEX IF NOT EXISTS idx_ai_rules_rule_type ON ai_rules(rule_type);
CREATE INDEX IF NOT EXISTS idx_ai_rules_setting_key ON ai_rules(setting_key) WHERE rule_type = 'setting';

-- 3. Update existing rules to have rule_type = 'condition' (backward compatibility)
UPDATE ai_rules
SET rule_type = 'condition'
WHERE rule_type IS NULL;

-- 4. Add comments for documentation
COMMENT ON COLUMN ai_rules.rule_type IS 'Type of rule: "condition" for IF-THEN rules based on detected concerns, "setting" for general AI behavior configuration';
COMMENT ON COLUMN ai_rules.setting_key IS 'For setting rules: the setting name (e.g., tone, depth, format, focus, always_include, avoid)';
COMMENT ON COLUMN ai_rules.setting_value IS 'For setting rules: the setting value (e.g., professional, detailed, bullets)';

-- 5. Example setting rules you can insert (optional - customize to your needs)

-- Example 1: Set professional tone
-- INSERT INTO ai_rules (user_id, company_id, name, rule_type, setting_key, setting_value, is_active, priority)
-- VALUES ('your-user-id', 'your-company-id', 'Professional Tone', 'setting', 'tone', 'professional and empathetic', true, 100);

-- Example 2: Set detailed analysis depth
-- INSERT INTO ai_rules (user_id, company_id, name, rule_type, setting_key, setting_value, is_active, priority)
-- VALUES ('your-user-id', 'your-company-id', 'Detailed Analysis', 'setting', 'depth', 'detailed and comprehensive', true, 100);

-- Example 3: Set structured format
-- INSERT INTO ai_rules (user_id, company_id, name, rule_type, setting_key, setting_value, is_active, priority)
-- VALUES ('your-user-id', 'your-company-id', 'Structured Format', 'setting', 'format', 'clear and structured with bullet points', true, 100);

-- Example 4: Always mention sun protection
-- INSERT INTO ai_rules (user_id, company_id, name, rule_type, setting_key, setting_value, is_active, priority)
-- VALUES ('your-user-id', 'your-company-id', 'Always Include SPF', 'setting', 'always_include', 'sun protection and daily SPF usage', true, 100);

-- Example 5: Focus on anti-aging
-- INSERT INTO ai_rules (user_id, company_id, name, rule_type, setting_key, setting_value, is_active, priority)
-- VALUES ('your-user-id', 'your-company-id', 'Focus Anti-Aging', 'setting', 'focus', 'anti-aging and wrinkle prevention', true, 90);

-- 6. Verify the changes
SELECT
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'ai_rules'
  AND column_name IN ('rule_type', 'setting_key', 'setting_value')
ORDER BY ordinal_position;

-- 7. Display sample of updated table structure
SELECT
    id,
    name,
    rule_type,
    condition,
    action,
    setting_key,
    setting_value,
    is_active,
    priority
FROM ai_rules
ORDER BY priority DESC, created_at DESC
LIMIT 10;
