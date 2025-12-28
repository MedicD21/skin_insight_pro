# Product Catalog & AI Recommendation Integration

This document explains how the Product Catalog integrates with AI skin analysis recommendations.

## Overview

The Skin Insight Pro app uses a multi-layered approach to generate product recommendations:

1. **AI Analysis** - External AI API analyzes skin images and client medical data
2. **Custom Products** - Admin-added products in the Product Catalog
3. **AI Rules** - Custom rules that link products to specific skin conditions
4. **Priority System** - Rules override default AI recommendations based on priority

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SKIN ANALYSIS FLOW                        │
└─────────────────────────────────────────────────────────────┘

1. Client Photo + Medical Data
   ↓
2. AI Analysis API (/aiapi/answerimage)
   - Analyzes skin type, concerns, hydration
   - Generates baseline recommendations
   ↓
3. AI Rules Processing (Priority-based)
   - Fetches active AI rules for the user
   - Matches conditions against analysis results
   - Overrides AI recommendations with custom products
   ↓
4. Product Recommendations
   - Final recommendations shown to esthetician
   - Includes custom products from catalog
```

---

## Database Schema

### Products Table

```sql
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id),
    name TEXT NOT NULL,
    brand TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    ingredients TEXT,
    skin_types TEXT[],  -- Array: Normal, Dry, Oily, Combination, Sensitive
    concerns TEXT[],    -- Array: Acne, Aging, Dark Spots, Redness, etc.
    image_url TEXT,     -- URL to product image in Supabase Storage
    price DECIMAL(10, 2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### AI Rules Table

```sql
CREATE TABLE ai_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id),
    name TEXT NOT NULL,
    condition TEXT NOT NULL,  -- When this condition is met
    product_id TEXT,          -- LINKS TO PRODUCTS TABLE (nullable for now)
    priority INT NOT NULL,    -- Higher priority = applied first
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Important:** The `product_id` field in `ai_rules` is currently stored as TEXT (not a foreign key). This allows flexibility for:
- Referencing products by ID
- Storing product names directly
- Supporting multiple products (comma-separated)

---

## How Products Connect to AI Recommendations

### Method 1: AI Rules with Product References

Admins can create AI rules that explicitly recommend specific products from the catalog:

**Example Rule:**
```
Name: Acne Treatment Protocol
Condition: Client has acne concerns OR oily skin type
Action: Recommend "Niacinamide Solution by The Ordinary"
Product ID: abc-123-def-456
Priority: 10
```

**How it works:**
1. During analysis, the app fetches all active AI rules for the user
2. Rules are sorted by priority (highest first)
3. Each rule's `condition` is evaluated against the analysis results
4. If condition matches, the associated product (via `product_id`) is recommended
5. Higher priority rules can override default AI suggestions

**Code Location:** [AIRulesView.swift](Sources/AIRulesView.swift)

### Method 2: Skin Type & Concern Matching

Products in the catalog include:
- `skin_types`: Which skin types the product is suitable for
- `concerns`: Which skin concerns the product addresses

**How it works:**
1. AI analyzes the image and identifies:
   - Skin type (e.g., "Oily")
   - Concerns (e.g., ["Acne", "Pores", "Oiliness"])
2. The app can query products that match:
   ```sql
   SELECT * FROM products
   WHERE 'Oily' = ANY(skin_types)
   AND ('Acne' = ANY(concerns) OR 'Pores' = ANY(concerns))
   AND is_active = TRUE
   ```
3. Matched products are suggested to the esthetician

**Code Location:** [Models.swift:249-279](Sources/Models.swift#L249-L279)

### Method 3: Manual Selection During Analysis

When performing a skin analysis, estheticians can:
1. View AI-generated recommendations
2. See products from their catalog that match the skin type/concerns
3. Manually select which products to use/recommend
4. Record products used in the `products_used` field

**Code Location:** [SkinAnalysisInputView.swift](Sources/SkinAnalysisInputView.swift)

---

## Data Flow Example

### Scenario: Client with Acne

1. **Photo Upload**
   - Esthetician uploads client photo
   - Includes medical data: medications, allergies, sensitivities

2. **AI Analysis**
   ```json
   {
     "skin_type": "Oily",
     "concerns": ["Acne", "Pores", "Oiliness"],
     "recommendations": [
       "Use gentle cleanser",
       "Consider salicylic acid treatment",
       "Avoid heavy moisturizers"
     ]
   }
   ```

3. **AI Rules Processing**
   - Fetch active rules for the user
   - Rule matches: "If Acne concern exists, recommend Niacinamide Solution"
   - Priority 10 rule overrides generic AI recommendation

4. **Product Catalog Query**
   ```swift
   // Fetch products matching the analysis
   let matchingProducts = products.filter { product in
       let matchesSkinType = product.skinTypes?.contains("Oily") ?? false
       let matchesConcerns = product.concerns?.contains(where: {
           ["Acne", "Pores", "Oiliness"].contains($0)
       }) ?? false
       return matchesSkinType && matchesConcerns && (product.isActive ?? false)
   }
   ```

5. **Final Recommendations**
   - AI baseline: "Salicylic acid treatment"
   - Rule override: "Niacinamide Solution by The Ordinary" ($6.50)
   - Catalog matches: 3 other products
   - Esthetician sees all options and selects best fit

---

## Adding Products to the AI System

### Option 1: Single Product Entry

1. Admin opens Product Catalog
2. Taps "Add Single Product"
3. Fills in:
   - Product name, brand, category
   - Description and key ingredients
   - **Skin types** it's suitable for
   - **Concerns** it addresses
   - **Price** and **image**
   - Active/inactive status
4. Product is immediately available for AI rules

**Code:** [AddProductView.swift](Sources/AddProductView.swift)

### Option 2: Mass Import via CSV

1. Admin downloads CSV template ([product_import_template.csv](product_import_template.csv))
2. Fills in product data in Excel/Google Sheets
3. Exports as CSV
4. Opens Product Catalog → "Import Products (CSV)"
5. Pastes CSV content or uploads file
6. Reviews preview of products to import
7. Confirms import
8. All products added at once

**Code:** [ProductImportView.swift](Sources/ProductImportView.swift)

**CSV Format:**
```csv
name,brand,category,description,ingredients,skin_types,concerns,price,image_url,is_active
Hydrating Serum,CeraVe,Serum,Lightweight serum,Hyaluronic Acid,Normal,Dryness,24.99,,TRUE
```

---

## Creating AI Rules for Products

### Step 1: Add Product to Catalog
- Ensure product exists in Product Catalog
- Note the product name or ID

### Step 2: Create AI Rule
1. Admin opens AI Rules section
2. Taps "Add AI Rule"
3. Fills in:
   - **Rule Name**: "Acne Treatment Protocol"
   - **Condition (When)**: "Client has acne concerns OR oily skin"
   - **Action (Then)**: "Recommend Niacinamide Solution for pore refinement"
   - **Priority**: 10 (higher = more important)
   - **Active**: ON
4. Saves rule

**Code:** [AIRulesView.swift](Sources/AIRulesView.swift)

### How Rules are Evaluated

Currently, the AI rules are stored and retrieved, but the **condition matching logic** needs to be implemented in the AI analysis flow.

**Current Status:**
- ✅ Rules can be created and stored
- ✅ Rules have priority levels
- ✅ Rules can reference products
- ⚠️ Condition evaluation not yet implemented
- ⚠️ Product recommendation override not yet implemented

**To Implement:**
1. After AI analysis returns results, fetch active AI rules
2. Parse each rule's `condition` field
3. Check if condition matches analysis results
4. If match, inject the recommended product into recommendations
5. Apply rules in priority order (high to low)

**Recommended Location:** [NetworkService.swift:687](Sources/NetworkService.swift#L687) in `analyzeImage` function

---

## API Endpoints

### Products

**Fetch Products:**
```
GET /rest/v1/products?user_id=eq.{userId}&order=created_at.desc
```

**Create Product:**
```
POST /rest/v1/products
{
  "user_id": "uuid",
  "name": "Product Name",
  "brand": "Brand",
  "category": "Category",
  "skin_types": ["Normal", "Dry"],
  "concerns": ["Dryness"],
  "image_url": "https://...",
  "price": 24.99,
  "is_active": true
}
```

**Update Product:**
```
PATCH /rest/v1/products?id=eq.{productId}
{
  "price": 29.99,
  "is_active": false
}
```

### AI Rules

**Fetch Rules:**
```
GET /rest/v1/ai_rules?user_id=eq.{userId}&order=priority.desc
```

**Create Rule:**
```
POST /rest/v1/ai_rules
{
  "user_id": "uuid",
  "name": "Rule Name",
  "condition": "Acne OR Oily",
  "product_id": "product-uuid",
  "priority": 10,
  "is_active": true
}
```

**Code:** [NetworkService.swift:844-1089](Sources/NetworkService.swift#L844-L1089)

---

## Best Practices

### For Admins

1. **Tag Products Accurately**
   - Select all applicable skin types
   - Include all relevant concerns
   - This enables automatic matching

2. **Use Descriptive Rule Names**
   - Good: "Acne Treatment - Niacinamide Protocol"
   - Bad: "Rule 1"

3. **Set Appropriate Priorities**
   - Critical protocols: Priority 10
   - General recommendations: Priority 5
   - Fallback options: Priority 1

4. **Keep Products Active**
   - Mark discontinued products as inactive
   - Don't delete them (preserves history)

5. **Include Pricing**
   - Helps with treatment planning
   - Enables cost calculations for clients

### For Developers

1. **Image Storage**
   - Product images stored in Supabase Storage bucket: `product-images`
   - Public read access enabled
   - Authenticated upload/update/delete

2. **RLS Policies**
   - Users can only see their own products
   - Enforced via `user_id = auth.uid()`
   - Same for AI rules

3. **Data Validation**
   - Skin types: Normal, Dry, Oily, Combination, Sensitive
   - Concerns: Acne, Aging, Dark Spots, Redness, Dryness, Oiliness, Fine Lines, Pores
   - Validate in both frontend and backend

---

## Future Enhancements

### 1. Automatic Product Matching
Implement logic to automatically suggest products based on:
- Matched skin types
- Matched concerns
- Previous successful treatments

### 2. Rule Condition Parser
Build a parser to evaluate rule conditions like:
- "Acne AND Oily"
- "Dryness OR Sensitivity"
- "Age > 30 AND Fine Lines"

### 3. Product Analytics
Track which products are:
- Most recommended by AI
- Most used by estheticians
- Most effective (based on progress metrics)

### 4. Inventory Management
- Track product stock levels
- Alert when running low
- Integration with suppliers

---

## Troubleshooting

### Products Not Showing in Recommendations

**Check:**
1. Is the product marked as `is_active = TRUE`?
2. Are `skin_types` and `concerns` filled in?
3. Does the product match the client's skin analysis?
4. Is the user logged in as admin who created the product?

### AI Rules Not Applied

**Check:**
1. Is the rule marked as `is_active = TRUE`?
2. Is the priority high enough?
3. Is the condition syntax correct?
4. Has the rule evaluation logic been implemented? (Currently pending)

### Image Upload Fails

**Check:**
1. Is the `product-images` bucket created in Supabase Storage?
2. Are storage policies set up correctly?
3. Is the image file under 5MB?
4. Is the user authenticated?

---

## Summary

The Product Catalog integration with AI recommendations works through:

1. **Products Table** - Stores spa's product inventory with skin type/concern tags
2. **AI Rules Table** - Links products to specific conditions with priority
3. **AI Analysis** - Baseline recommendations from image analysis
4. **Rule Override System** - Custom rules override AI based on priority
5. **Manual Selection** - Esthetician can choose from matched products

**Key Files:**
- [Models.swift](Sources/Models.swift) - Product and AIRule data models
- [NetworkService.swift](Sources/NetworkService.swift) - API calls for products, rules, AI analysis
- [ProductCatalogView.swift](Sources/ProductCatalogView.swift) - Product management UI
- [AddProductView.swift](Sources/AddProductView.swift) - Add/edit individual products
- [ProductImportView.swift](Sources/ProductImportView.swift) - Bulk CSV import
- [AIRulesView.swift](Sources/AIRulesView.swift) - AI rule management UI

**Database Scripts:**
- [SUPABASE_PRODUCT_SCHEMA_UPDATE.sql](SUPABASE_PRODUCT_SCHEMA_UPDATE.sql) - Add image_url and price columns
- [SUPABASE_RLS_POLICIES.sql](SUPABASE_RLS_POLICIES.sql) - Row level security policies

**Templates:**
- [product_import_template.csv](product_import_template.csv) - Sample CSV for mass import
- [PRODUCT_IMPORT_TEMPLATE.md](PRODUCT_IMPORT_TEMPLATE.md) - CSV format documentation
