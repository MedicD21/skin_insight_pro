-- Add usage_guidelines column to products table
-- This column stores instructions on how to use the product: frequency, application method, timing, tips
-- The AI will use this information to provide better product recommendations

ALTER TABLE products
ADD COLUMN IF NOT EXISTS usage_guidelines TEXT;

-- Add comment to column for documentation
COMMENT ON COLUMN products.usage_guidelines IS 'Product usage instructions: frequency, application method, when to apply, tips (e.g., Apply twice daily, morning and night. Use pea-sized amount on clean, damp skin.)';

-- Example: Update an existing product with usage guidelines
-- UPDATE products
-- SET usage_guidelines = 'Apply twice daily, morning and night. Use a pea-sized amount on clean, damp skin. Pat gently around eye area, avoiding direct contact with eyes. Follow with moisturizer.'
-- WHERE name = 'Hydrating Eye Cream';
