# Skin Insight Pro - Database Schema

## Database: Supabase (PostgreSQL)

This document describes the complete database schema for the Skin Insight Pro application.

---

## Table: `users`

User accounts (including admins)

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  password TEXT, -- hashed password (null for Apple Sign In users)
  provider TEXT NOT NULL DEFAULT 'email', -- 'email' or 'apple'
  apple_user_id TEXT UNIQUE, -- Apple user identifier for Sign in with Apple
  first_name TEXT,
  last_name TEXT,
  is_admin BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_apple_user_id ON users(apple_user_id);
CREATE INDEX idx_users_is_admin ON users(is_admin);
```

**Row Level Security (RLS):**
```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can only read their own data
CREATE POLICY "Users can view own data" ON users
  FOR SELECT USING (auth.uid() = id);

-- Users can update their own data (except is_admin)
CREATE POLICY "Users can update own data" ON users
  FOR UPDATE USING (auth.uid() = id);
```

---

## Table: `clients`

Client/customer information for estheticians

```sql
CREATE TABLE clients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  notes TEXT,
  medical_history TEXT,
  allergies TEXT,
  known_sensitivities TEXT,
  medications TEXT, -- NEW: Current medications
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_clients_user_id ON clients(user_id);
CREATE INDEX idx_clients_name ON clients(name);
CREATE INDEX idx_clients_email ON clients(email);
```

**Row Level Security:**
```sql
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

-- Users can only see their own clients
CREATE POLICY "Users can view own clients" ON clients
  FOR SELECT USING (auth.uid() = user_id);

-- Users can create their own clients
CREATE POLICY "Users can create own clients" ON clients
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own clients
CREATE POLICY "Users can update own clients" ON clients
  FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own clients
CREATE POLICY "Users can delete own clients" ON clients
  FOR DELETE USING (auth.uid() = user_id);
```

---

## Table: `skin_analyses`

Skin analysis results with AI recommendations

```sql
CREATE TABLE skin_analyses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  analysis_results JSONB NOT NULL, -- AnalysisData JSON
  notes TEXT,
  client_medical_history TEXT, -- Snapshot at time of analysis
  client_allergies TEXT,
  client_known_sensitivities TEXT,
  client_medications TEXT, -- NEW: Medications at time of analysis
  products_used TEXT,
  treatments_performed TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_skin_analyses_client_id ON skin_analyses(client_id);
CREATE INDEX idx_skin_analyses_user_id ON skin_analyses(user_id);
CREATE INDEX idx_skin_analyses_created_at ON skin_analyses(created_at DESC);
```

**AnalysisData JSON Structure:**
```json
{
  "skin_type": "Combination",
  "hydration_level": 7,
  "sensitivity": "Moderate",
  "concerns": ["Fine Lines", "Dark Spots"],
  "pore_condition": "Visible",
  "skin_health_score": 75,
  "recommendations": [
    "Use hyaluronic acid serum daily",
    "Apply vitamin C in the morning"
  ],
  "medical_considerations": [
    "Retinol may cause irritation due to sensitive skin"
  ],
  "progress_notes": [
    "Improved hydration since last visit"
  ]
}
```

**Row Level Security:**
```sql
ALTER TABLE skin_analyses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own analyses" ON skin_analyses
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own analyses" ON skin_analyses
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```

---

## Table: `products`

Product catalog for spas (admin-managed)

```sql
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- Owner (spa)
  name TEXT NOT NULL,
  brand TEXT NOT NULL,
  category TEXT NOT NULL, -- 'Cleanser', 'Serum', 'Moisturizer', etc.
  description TEXT,
  ingredients TEXT,
  skin_types TEXT[] DEFAULT '{}', -- Array: ['Dry', 'Oily', 'Combination']
  concerns TEXT[] DEFAULT '{}', -- Array: ['Acne', 'Aging', 'Dark Spots']
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_products_user_id ON products(user_id);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_is_active ON products(is_active);
CREATE INDEX idx_products_skin_types ON products USING GIN(skin_types);
CREATE INDEX idx_products_concerns ON products USING GIN(concerns);
```

**Row Level Security:**
```sql
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Users can view their own products
CREATE POLICY "Users can view own products" ON products
  FOR SELECT USING (auth.uid() = user_id);

-- Only admins can create products
CREATE POLICY "Admins can create products" ON products
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = TRUE)
  );

-- Only admins can update products
CREATE POLICY "Admins can update products" ON products
  FOR UPDATE USING (
    auth.uid() = user_id AND
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = TRUE)
  );

-- Only admins can delete products
CREATE POLICY "Admins can delete products" ON products
  FOR DELETE USING (
    auth.uid() = user_id AND
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = TRUE)
  );
```

---

## Table: `ai_rules`

AI recommendation rules (admin-configured)

```sql
CREATE TABLE ai_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  condition TEXT NOT NULL, -- e.g., "skin_type = 'Dry' AND concerns CONTAINS 'Aging'"
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  priority INTEGER DEFAULT 0, -- Higher priority rules applied first
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_ai_rules_user_id ON ai_rules(user_id);
CREATE INDEX idx_ai_rules_product_id ON ai_rules(product_id);
CREATE INDEX idx_ai_rules_priority ON ai_rules(priority DESC);
CREATE INDEX idx_ai_rules_is_active ON ai_rules(is_active);
```

**Example Rules:**
- **Rule 1:** "If skin_type = 'Dry' AND concerns contains 'Aging' → Recommend Product: CeraVe Hydrating Cleanser" (Priority: 10)
- **Rule 2:** "If concerns contains 'Acne' AND sensitivity = 'Low' → Recommend Product: Paula's Choice BHA Exfoliant" (Priority: 8)

**Row Level Security:**
```sql
ALTER TABLE ai_rules ENABLE ROW LEVEL SECURITY;

-- Users can view their own rules
CREATE POLICY "Users can view own rules" ON ai_rules
  FOR SELECT USING (auth.uid() = user_id);

-- Only admins can create rules
CREATE POLICY "Admins can create rules" ON ai_rules
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = TRUE)
  );

-- Only admins can update rules
CREATE POLICY "Admins can update rules" ON ai_rules
  FOR UPDATE USING (
    auth.uid() = user_id AND
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = TRUE)
  );

-- Only admins can delete rules
CREATE POLICY "Admins can delete rules" ON ai_rules
  FOR DELETE USING (
    auth.uid() = user_id AND
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = TRUE)
  );
```

---

## Database Functions & Triggers

### Auto-update timestamps

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON clients
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ai_rules_updated_at BEFORE UPDATE ON ai_rules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

## API Endpoints

The app uses generic CRUD endpoints with table names:

### Base URL
```
https://api.lastapp.ai
```

### Authentication
```
POST /data/login
Body: { app_id, email, password, provider }
Response: AppUser object

POST /data/apple-login
Body: { app_id, apple_user_id, email, first_name?, last_name? }
Response: AppUser object
```

### Generic CRUD
```
GET /data?app_id={id}&table_name={table}&user_id={uid}
Response: Array of objects

POST /data
Body: { app_id, table_name, data: {...} }
Response: Created object

DELETE /data?app_id={id}&table_name={table}&id={record_id}
Response: Success
```

### File Upload
```
POST /data/upload
Body: multipart/form-data with app_id, user_id, file
Response: { url: "https://..." }
```

### AI Analysis
```
POST /aiapi/answerimage
Body: multipart/form-data with:
  - app_id
  - image
  - medical_history?
  - allergies?
  - known_sensitivities?
  - medications? (NEW)
  - manual_skin_type?
  - manual_hydration_level?
  - manual_sensitivity?
  - manual_pore_condition?
  - manual_concerns?
  - products_used?
  - treatments_performed?
  - previous_analyses? (JSON array)
Response: AIAnalysisResponse (JSON)
```

---

## Setup Instructions

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Create new project (free tier)
3. Note your project URL and API key

### 2. Run SQL Schema
Copy all table creation SQL from this document and run in Supabase SQL Editor

### 3. Enable Row Level Security
All tables have RLS enabled by default - policies are defined above

### 4. Configure Backend
Update `AppConstants.baseUrl` to point to your backend API that integrates with Supabase

---

## Data Flow

1. **User Sign In** → Creates/retrieves user from `users` table
2. **Add Client** → Insert into `clients` table
3. **Perform Analysis** →
   - Upload image to storage
   - Call AI API with client medical data + medications
   - Save result to `skin_analyses` table
4. **Admin: Add Product** → Insert into `products` table
5. **Admin: Create Rule** → Insert into `ai_rules` table with product_id reference
6. **AI Analysis (with rules)** → AI checks active rules, matches conditions, recommends products

---

## Admin User Setup

To make a user an admin:

```sql
UPDATE users
SET is_admin = TRUE
WHERE email = 'admin@example.com';
```

---

## Backup & Security

- **Automated Backups:** Supabase provides daily backups on all plans
- **RLS Enabled:** All tables have Row Level Security enabled
- **Encryption:** Data encrypted at rest and in transit
- **API Keys:** Use environment variables, never commit to code

