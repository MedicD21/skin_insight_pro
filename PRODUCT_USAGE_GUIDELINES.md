# Product Usage Guidelines Feature

## Overview
Added a new "Usage Guidelines" field to the product catalog that allows estheticians to specify how each product should be used. The AI now reads and considers this information when making product recommendations.

## Changes Made

### 1. Database Schema (`add_product_usage_guidelines.sql`)
- Added `usage_guidelines` TEXT column to the `products` table
- Column stores detailed usage instructions including:
  - Application frequency (e.g., "twice daily")
  - Application method (e.g., "pea-sized amount")
  - Timing (e.g., "morning and night")
  - Tips and warnings (e.g., "avoid direct eye contact")

**To apply the migration:**
```sql
-- Run this in your Supabase SQL editor
ALTER TABLE products
ADD COLUMN IF NOT EXISTS usage_guidelines TEXT;
```

### 2. iOS App Model Updates

**Files Modified:**
- `Sources/Models.swift`
  - Added `usageGuidelines: String?` to `Product` struct
  - Added `usageGuidelines: String?` to `ProductData` struct
  - Added `usage_guidelines` to `CodingKeys` enum

### 3. Product Entry Form

**Files Modified:**
- `Sources/AddProductView.swift`
  - Added `@State private var usageGuidelines = ""` state variable
  - Added `.usageGuidelines` to `Field` enum
  - Added new text editor field in the Details section with icon "lightbulb"
  - Included in form validation and save logic
  - Placeholder text provides examples for estheticians

**UI Location:**
The new field appears in the "Details" section, after "All Ingredients" with the following placeholder:
> "How to use this product: frequency, application method, when to apply, tips (e.g., Apply twice daily, morning and night. Use pea-sized amount on clean, damp skin. Pat gently, don't rub.)"

### 4. AI Integration

**Files Modified:**
- `Sources/AIAnalysisService.swift`
  - Updated product catalog prompt to include usage guidelines
  - AI now sees: `"Product X" | Usage: [usage guidelines]`
  - Helps AI make more informed recommendations based on:
    - Application frequency requirements
    - Layering order considerations
    - Skin type compatibility based on application method
    - Time of day usage (AM/PM products)

## Benefits

### For Estheticians:
1. **Better Product Education** - Document how each product should be used
2. **Consistency** - Ensure all staff recommend products with correct usage
3. **Client Education** - AI can include usage tips in recommendations
4. **Product Differentiation** - Similar products can be distinguished by usage method

### For AI Recommendations:
1. **Smarter Matching** - AI understands if products conflict (e.g., don't recommend 3 serums if each says "apply first")
2. **Better Timing** - Can recommend AM vs PM products appropriately
3. **Frequency Awareness** - Won't over-recommend products with intensive usage requirements
4. **Application Method** - Can consider if client needs simple or complex routines

## Example Usage Guidelines

```
Hydrating Serum:
"Apply twice daily after cleansing. Use 2-3 drops on damp skin. Pat gently, focusing on dry areas. Follow with moisturizer. Can be used morning and night."

Retinol Cream:
"Use only at night, 2-3 times per week initially. Apply pea-sized amount to dry skin after cleansing. Avoid eye area. Always use SPF 30+ in the morning. Start slowly to build tolerance."

Vitamin C Serum:
"Apply every morning after cleansing, before moisturizer. Use 3-4 drops on clean, dry skin. Allow to absorb for 60 seconds before applying other products. Store in cool, dark place to maintain potency."

Gentle Cleanser:
"Use morning and night. Apply to damp skin, massage for 30-60 seconds, rinse with lukewarm water. Can double cleanse at night if wearing makeup."
```

## Testing

1. ✅ Build succeeds
2. ✅ Model includes new field
3. ✅ Form displays new field
4. ✅ AI prompt includes usage guidelines
5. ⏳ Database migration needs to be run in Supabase

## Next Steps

1. **Run the SQL migration** in Supabase SQL editor
2. **Add usage guidelines** to existing products in the catalog
3. **Test AI recommendations** with products that have usage guidelines
4. **Train staff** on filling out usage guidelines effectively

## Migration Instructions

### Step 1: Run SQL Migration
1. Go to Supabase Dashboard → SQL Editor
2. Create new query
3. Paste contents of `add_product_usage_guidelines.sql`
4. Run the query

### Step 2: Add Usage Guidelines to Existing Products
1. Open Products tab in the app
2. Edit each product
3. Scroll to "Details" section
4. Fill in "Usage Guidelines" field with application instructions
5. Save product

### Step 3: Verify AI Integration
1. Run a skin analysis
2. Check that product recommendations reference usage when appropriate
3. Verify AI doesn't recommend conflicting products (e.g., multiple "apply first" serums)

## Notes

- Usage guidelines are optional - products without them still work
- AI uses this info to improve recommendations, not as hard rules
- More detailed usage guidelines = better AI recommendations
- Consider including brand-specific tips and warnings
