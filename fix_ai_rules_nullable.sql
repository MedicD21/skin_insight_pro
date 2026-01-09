-- Fix AI Rules Schema - Make condition and action nullable for setting-type rules
-- Run this in Supabase Dashboard > SQL Editor

-- 1. Make condition and action fields nullable (they should only be required for conditional rules)
ALTER TABLE ai_rules
ALTER COLUMN condition DROP NOT NULL,
ALTER COLUMN action DROP NOT NULL;

-- 2. Add check constraint to ensure conditional rules have condition and action
-- (Setting rules don't need them)
ALTER TABLE ai_rules
ADD CONSTRAINT check_conditional_rule_fields
CHECK (
    (rule_type = 'condition' AND condition IS NOT NULL AND action IS NOT NULL)
    OR
    (rule_type = 'setting' AND setting_key IS NOT NULL AND setting_value IS NOT NULL)
);

-- 3. Add comments for clarity
COMMENT ON CONSTRAINT check_conditional_rule_fields ON ai_rules IS 'Ensures conditional rules have condition/action and setting rules have setting_key/setting_value';

-- 4. Verify the changes
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'ai_rules'
  AND column_name IN ('condition', 'action', 'setting_key', 'setting_value', 'rule_type')
ORDER BY ordinal_position;

-- 5. Test by viewing table structure
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
