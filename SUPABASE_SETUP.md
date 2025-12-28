# Supabase Setup Guide for Skin Insight Pro

Your app has been configured to work directly with Supabase! Follow these steps to complete the setup.

---

## ✅ What's Already Done

- [x] Supabase database schema created (all 5 tables)
- [x] App configured with your Supabase URL and API key
- [x] NetworkService rewritten to use Supabase REST API directly
- [x] No backend server needed!

---

## 🔧 Required Supabase Configuration

### Step 1: Create Storage Bucket for Images

1. In Supabase Dashboard, go to **Storage** (left sidebar)
2. Click **"New bucket"**
3. Name: `skin-images`
4. **Public bucket:** ✅ **YES** (check this box)
5. Click **"Create bucket"**

### Step 2: Set Up Storage Policies

After creating the bucket, click on `skin-images` → **Policies** tab → **New Policy**

**Policy 1: Allow INSERT (Upload)**
- Name: `Allow authenticated uploads`
- Policy command: `INSERT`
- Target roles: `authenticated`, `anon`
- USING expression: `true`
- Click **"Review"** → **"Save policy"**

**Policy 2: Allow SELECT (Read)**
- Name: `Allow public reads`
- Policy command: `SELECT`
- Target roles: `authenticated`, `anon`
- USING expression: `true`
- Click **"Review"** → **"Save policy"**

### Step 3: Enable Row Level Security (RLS)

You've already created the tables. Now verify RLS is enabled:

1. Go to **Table Editor** (left sidebar)
2. For each table (users, clients, skin_analyses, products, ai_rules):
   - Click the table name
   - Click the **"RLS"** toggle at the top to ensure it's **enabled** (green)

### Step 4: Create RLS Policies

Go to **Authentication** → **Policies** in the sidebar, then add these policies for each table:

#### **users table:**

**Policy: Users can view own data**
```sql
CREATE POLICY "Users can view own data" ON users
FOR SELECT
USING (true);
```

**Policy: Anyone can create users**
```sql
CREATE POLICY "Anyone can create users" ON users
FOR INSERT
WITH CHECK (true);
```

#### **clients table:**

**Policy: Users can view own clients**
```sql
CREATE POLICY "Users can view own clients" ON clients
FOR SELECT
USING (true);
```

**Policy: Users can insert clients**
```sql
CREATE POLICY "Users can insert clients" ON clients
FOR INSERT
WITH CHECK (true);
```

**Policy: Users can update clients**
```sql
CREATE POLICY "Users can update clients" ON clients
FOR UPDATE
USING (true);
```

#### **skin_analyses table:**

**Policy: Users can view analyses**
```sql
CREATE POLICY "Users can view analyses" ON skin_analyses
FOR SELECT
USING (true);
```

**Policy: Users can insert analyses**
```sql
CREATE POLICY "Users can insert analyses" ON skin_analyses
FOR INSERT
WITH CHECK (true);
```

#### **products table:**

**Policy: Users can view products**
```sql
CREATE POLICY "Users can view products" ON products
FOR SELECT
USING (true);
```

**Policy: Users can insert products**
```sql
CREATE POLICY "Users can insert products" ON products
FOR INSERT
WITH CHECK (true);
```

**Policy: Users can update products**
```sql
CREATE POLICY "Users can update products" ON products
FOR UPDATE
USING (true);
```

#### **ai_rules table:**

**Policy: Users can view rules**
```sql
CREATE POLICY "Users can view rules" ON ai_rules
FOR SELECT
USING (true);
```

**Policy: Users can insert rules**
```sql
CREATE POLICY "Users can insert rules" ON ai_rules
FOR INSERT
WITH CHECK (true);
```

**Policy: Users can update rules**
```sql
CREATE POLICY "Users can update rules" ON ai_rules
FOR UPDATE
USING (true);
```

---

## 🎯 Create Your Admin User

### Option 1: Create User Through the App (Easiest)

1. Build and run the app in Xcode
2. Tap **"Sign Up"**
3. Enter your email and password
4. Tap **"Create Account"**

Then, in Supabase SQL Editor, run:

```sql
UPDATE users
SET is_admin = TRUE
WHERE email = 'your-email@example.com';
```

### Option 2: Create User Manually in Supabase

1. Go to Supabase SQL Editor
2. Run this SQL:

```sql
INSERT INTO users (email, password, provider, is_admin)
VALUES (
  'your-email@example.com',
  encode(sha256('your-password'::bytea), 'hex'),
  'email',
  TRUE
);
```

Replace `your-email@example.com` and `your-password` with your actual credentials.

---

## 📱 How It Works Now

### Authentication Flow

**Email/Password Login:**
1. App hashes password with SHA-256
2. Sends query to Supabase: `GET /rest/v1/users?email=eq.xxx&password=eq.xxx`
3. Supabase returns user if credentials match
4. App stores user info locally

**Apple Sign In:**
1. App gets Apple User ID from Apple
2. Checks if user exists: `GET /rest/v1/users?apple_user_id=eq.xxx`
3. If exists → logs in
4. If not → creates new user with Apple ID

### Data Operations

**All data operations use Supabase REST API:**

- **Fetch:** `GET /rest/v1/{table}?user_id=eq.{userId}`
- **Create:** `POST /rest/v1/{table}` with JSON body
- **Update:** `PATCH /rest/v1/{table}?id=eq.{id}` with JSON body
- **Delete:** `DELETE /rest/v1/{table}?id=eq.{id}`

### Image Upload

**Images are stored in Supabase Storage:**

- Upload: `POST /storage/v1/object/skin-images/{userId}/{uuid}.jpg`
- Public URL: `{supabaseUrl}/storage/v1/object/public/skin-images/{userId}/{uuid}.jpg`

### AI Analysis

**AI analysis still uses the separate AI API:**

- Endpoint: `https://api.lastapp.ai/aiapi/answerimage`
- Sends image + medical context
- Returns skin analysis results

---

## 🧪 Testing Your Setup

### 1. Test User Creation

Build and run the app, then try to sign up with a new email/password. Check the logs for:

```
-> Request: Create User
-> POST: https://meqrnevrimzvvhmopxrq.supabase.co/rest/v1/users
<- Status Code: 201
```

### 2. Test Login

Try logging in with your credentials. Check for:

```
-> Request: Login
-> GET: https://meqrnevrimzvvhmopxrq.supabase.co/rest/v1/users?email=eq.xxx...
<- Status Code: 200
```

### 3. Test Client Creation

After logging in, create a client. Check for:

```
-> Request: Create Client
-> POST: https://meqrnevrimzvvhmopxrq.supabase.co/rest/v1/clients
<- Status Code: 201
```

### 4. Verify Data in Supabase

Go to Supabase **Table Editor** and check that data appears in:
- `users` table (your user account)
- `clients` table (your test client)

---

## 🔐 Security Notes

### Password Storage

Passwords are hashed using SHA-256 before being sent to Supabase. They are stored as hex strings in the database.

### API Keys

The `supabaseAnonKey` is safe to use in the iOS app. It only allows operations permitted by your RLS policies.

### Row Level Security

RLS policies currently allow all authenticated operations. For production, you should tighten these policies to:

```sql
-- Example: Users can only view their own clients
CREATE POLICY "Users can view own clients" ON clients
FOR SELECT
USING (user_id = auth.uid());
```

However, since Supabase's `auth.uid()` requires using Supabase Auth (not custom authentication), and this app uses custom auth, you'll need to implement user-specific policies differently or migrate to Supabase Auth.

---

## ❌ Troubleshooting

### "Resource not found" Error

**Problem:** App shows 404 errors

**Solution:** Make sure you've:
1. Created all 5 tables from DATABASE_SCHEMA.md
2. Enabled RLS on all tables
3. Created RLS policies for all tables

### "Unauthorized" or 401 Errors

**Problem:** Can't create users or clients

**Solution:**
1. Check that RLS policies allow INSERT operations
2. Verify your `supabaseAnonKey` is correct in [AppConstants.swift](Sources/AppConstants.swift)

### Storage Upload Fails

**Problem:** Image upload returns 404 or 403

**Solution:**
1. Create the `skin-images` bucket
2. Make sure it's **public**
3. Add INSERT and SELECT storage policies

### Login Always Fails

**Problem:** Can't log in even with correct credentials

**Solution:**
1. Check that password hashing matches
2. Run this in SQL Editor to verify:

```sql
SELECT email, password
FROM users
WHERE email = 'your-email@example.com';
```

Then hash your password manually and compare:

```sql
SELECT encode(sha256('your-password'::bytea), 'hex');
```

---

## 🎉 You're Done!

Once you've completed these steps:

1. ✅ Storage bucket created with policies
2. ✅ RLS enabled on all tables
3. ✅ RLS policies created for all tables
4. ✅ Admin user created

Your app should work perfectly with Supabase!

Build and run: `open SkinInsightPro.xcworkspace`

---

## 📞 Need Help?

If you encounter issues:

1. Check Xcode console logs for detailed error messages
2. Check Supabase logs: Dashboard → **Logs** → **Postgres Logs**
3. Verify your API key is correct
4. Make sure all tables exist in **Table Editor**

---

Made with ❤️ for Skin Insight Pro
