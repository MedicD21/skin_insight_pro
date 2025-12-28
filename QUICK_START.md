# 🚀 Quick Start Guide - Supabase Auth Integration

Your app has been completely updated to use **proper Supabase Authentication**! Follow these steps to get everything working.

---

## ✅ What's Changed

Your app now uses:
- **Supabase Auth API** instead of custom authentication
- **JWT tokens** for secure authentication
- **Row Level Security (RLS)** with `auth.uid()` for data isolation
- **Automatic token management** with refresh tokens

---

## 🔧 Setup Steps (Do This Now!)

### Step 1: Update RLS Policies in Supabase

This is **REQUIRED** for the app to work!

1. Open Supabase Dashboard: https://meqrnevrimzvvhmopxrq.supabase.co
2. Go to **SQL Editor** (left sidebar)
3. Click **"New query"**
4. Open the file **`SUPABASE_RLS_POLICIES.sql`** from your project
5. Copy **ALL** the content
6. Paste into SQL Editor
7. Click **"Run"**

You should see: "Success. No rows returned" - **This is correct!**

The script will:
- ✅ Delete all old insecure policies
- ✅ Create new policies using `auth.uid()`
- ✅ Secure your data so users can only see their own records

---

### Step 2: Enable Email Authentication

1. In Supabase Dashboard → **Authentication** → **Providers**
2. Make sure **Email** is **enabled** (it should be by default)
3. For testing, **disable** "Confirm email" (you can enable it later)
4. Click **"Save"**

---

### Step 3: Test the App

1. Open your project in Xcode:
   ```bash
   cd /Users/dustinschaaf/Desktop/skin_insight_pro
   open SkinInsightPro.xcworkspace
   ```

2. Build and run the app (⌘R)

3. **Create a new account:**
   - Tap "Sign Up"
   - Enter email: `DSchaaf12@me.com`
   - Enter a password (remember it!)
   - Tap "Create Account"

4. **Check the console** for:
   ```
   -> Request: Signup with Supabase Auth
   -> POST: https://meqrnevrimzvvhmopxrq.supabase.co/auth/v1/signup
   <- Status Code: 200
   ```

   If you see **Status Code: 200**, authentication is working! ✅

---

### Step 4: Make Yourself Admin

1. After signing up, go to Supabase Dashboard → **SQL Editor**
2. Run this query:

```sql
UPDATE users
SET is_admin = TRUE
WHERE email = 'DSchaaf12@me.com';
```

3. You should see: "Success. No rows returned" or "1 row affected"

4. Restart the app to see admin features!

---

## 🎯 What to Test

### Test Authentication ✅
- [x] Sign up with email/password
- [x] Log out
- [x] Log in with same credentials
- [x] Check that JWT tokens are saved (check console logs)

### Test Data Isolation ✅
- [x] Create a client
- [x] Make sure you can see your own clients
- [x] Try to access data - RLS should only show YOUR data

### Test Admin Features ✅
- [x] After making yourself admin, check Profile
- [x] You should see "Admin Tools" section
- [x] Try accessing Product Catalog
- [x] Try accessing AI Rules

---

## 🔐 How It Works Now

### Signup Flow
1. User enters email/password
2. App calls `/auth/v1/signup` on Supabase
3. Supabase creates auth user + returns JWT tokens
4. App saves tokens to UserDefaults
5. App creates user profile in `users` table

### Login Flow
1. User enters email/password
2. App calls `/auth/v1/token?grant_type=password`
3. Supabase validates and returns JWT tokens
4. App saves tokens and fetches user profile

### Authenticated Requests
1. All requests include: `Authorization: Bearer <JWT_TOKEN>`
2. Supabase validates token
3. RLS policies use `auth.uid()` to filter data
4. Users can ONLY see their own data

---

## 🐛 Troubleshooting

### "Invalid grant" error
**Problem:** Can't log in
**Solution:** Email or password is wrong, or user doesn't exist yet

### "Row Level Security" error
**Problem:** Can't create clients/products
**Solution:** Make sure you ran the RLS policies SQL script

### "User already registered" error
**Problem:** Email already exists
**Solution:** Use login instead of signup, or use a different email

### Can't see admin features
**Problem:** Not seeing Product Catalog or AI Rules
**Solution:** Make sure you ran the `UPDATE users SET is_admin = TRUE` query

### Apple Sign In error 1000
**Problem:** Apple Sign In still shows error
**Solution:** This requires Apple Developer configuration - we can fix this later

---

## 📱 Files Changed

### Updated Files:
1. **[AppConstants.swift](Sources/AppConstants.swift)** - Added token storage keys
2. **[NetworkService.swift](Sources/NetworkService.swift)** - Complete rewrite for Supabase Auth
3. **[AuthenticationManager.swift](Sources/AuthenticationManager.swift)** - Updated token management

### New Files:
1. **[SUPABASE_RLS_POLICIES.sql](SUPABASE_RLS_POLICIES.sql)** - SQL script to run
2. **[SUPABASE_AUTH_SETUP.md](SUPABASE_AUTH_SETUP.md)** - Detailed documentation
3. **[QUICK_START.md](QUICK_START.md)** - This file!

---

## ✨ Security Improvements

### Before (Custom Auth):
- ❌ Manual password hashing
- ❌ Permissive RLS (anyone could access any data)
- ❌ No session management
- ❌ No token expiration

### After (Supabase Auth):
- ✅ Supabase handles password hashing (bcrypt)
- ✅ Secure RLS with `auth.uid()`
- ✅ JWT tokens with automatic expiration
- ✅ Refresh token support
- ✅ Industry best practices

---

## 🎉 You're Almost Done!

Once you complete the 4 setup steps above:
1. ✅ Run SQL script for RLS policies
2. ✅ Enable email authentication
3. ✅ Test signup/login
4. ✅ Make yourself admin

Your app will be fully functional with **secure authentication**! 🔐

---

## 📞 Need Help?

Check the detailed docs:
- [SUPABASE_AUTH_SETUP.md](SUPABASE_AUTH_SETUP.md) - Full setup guide
- [SUPABASE_RLS_POLICIES.sql](SUPABASE_RLS_POLICIES.sql) - SQL script

Console logs will show all API requests - check for status codes:
- **200-299** = Success ✅
- **400** = Bad request (invalid credentials)
- **401** = Unauthorized (missing/invalid token)
- **403** = Forbidden (RLS policy blocked)

---

**Ready to test?** Build and run the app! 🚀

```bash
open SkinInsightPro.xcworkspace
```
