# GOD Mode Configuration

**Date:** 2026-01-07
**Account:** dschaaf12@me.com

## Overview

GOD mode is a special developer/owner privilege that bypasses ALL subscription checks and usage limits. This allows you to test the full functionality of the app without needing to purchase subscriptions or worry about monthly caps.

---

## What GOD Mode Does

When enabled, GOD mode:
- ✅ Bypasses Apple Vision free tier limit (normally 5/month)
- ✅ Bypasses Claude subscription requirement
- ✅ Bypasses monthly usage caps
- ✅ Shows "GOD MODE" as tier in analytics
- ✅ Works on both client-side and server-side validation
- ✅ Unlimited analyses with both Apple Vision and Claude

---

## Setup Instructions

### Step 1: Add `god_mode` Column to Database

Run this in **Supabase Dashboard → SQL Editor**:

```sql
-- Add god_mode column
ALTER TABLE users
ADD COLUMN IF NOT EXISTS god_mode BOOLEAN DEFAULT false;

-- Add comment
COMMENT ON COLUMN users.god_mode IS 'GOD mode: Bypass all subscription checks and limits (for developer/owner only)';

-- Create index
CREATE INDEX IF NOT EXISTS idx_users_god_mode ON users(god_mode) WHERE god_mode = true;
```

### Step 2: Enable GOD Mode for Your Account

Run this in **Supabase Dashboard → SQL Editor**:

```sql
UPDATE users
SET god_mode = true
WHERE email = 'dschaaf12@me.com';

-- Verify
SELECT
    id,
    email,
    first_name,
    last_name,
    is_admin,
    god_mode
FROM users
WHERE email = 'dschaaf12@me.com';
```

You should see: `god_mode: true`

### Step 3: Update Server-Side Validation Function

Run the updated function in **Supabase Dashboard → SQL Editor**:

```bash
# Copy contents of create_claude_usage_tracking.sql
# Paste into SQL Editor
# Execute
```

This updates `record_claude_usage` to check for GOD mode first.

### Step 4: Test GOD Mode

1. **Build and run the app** (code changes are already in place)
2. **Log in with:** dschaaf12@me.com
3. **Try the following:**
   - Create 10+ Apple Vision analyses (should work - no 5/month limit)
   - Use Claude analysis without subscription (should work)
   - Check Profile view - may show "GOD MODE" tier

---

## Code Changes Made

### 1. Models.swift ([Models.swift:9](Sources/Models.swift#L9))

Added `godMode` property to `AppUser`:

```swift
struct AppUser: Identifiable, Hashable, Codable {
    var id: String?
    var email: String?
    var provider: String?
    var isAdmin: Bool?
    var isCompanyAdmin: Bool?
    var godMode: Bool?  // NEW
    // ... other fields

    enum CodingKeys: String, CodingKey {
        // ... other cases
        case godMode = "god_mode"  // NEW
    }
}
```

### 2. StoreKitManager.swift ([StoreKitManager.swift:199-205](Sources/StoreKitManager.swift#L199-L205))

Updated `hasActiveSubscription()` to check GOD mode:

```swift
func hasActiveSubscription() -> Bool {
    // GOD mode users always have access
    if AuthenticationManager.shared.currentUser?.godMode == true {
        return true
    }
    return !purchasedProductIDs.isEmpty
}
```

### 3. Database Function: `record_claude_usage`

Updated to check GOD mode first:

```sql
-- 0. Check if user has GOD mode enabled
SELECT god_mode INTO v_is_god_mode
FROM users
WHERE id::text = p_user_id;

-- GOD mode users bypass all checks
IF v_is_god_mode = true THEN
    v_result := json_build_object(
        'allowed', true,
        'current_usage', 0,
        'monthly_cap', 999999,
        'tier', 'GOD MODE',
        'remaining', 999999
    );
    RETURN v_result;
END IF;
```

---

## How It Works

### Client-Side Check (Apple Vision Free Tier)

When you tap "New Skin Analysis":

1. App checks: `storeManager.hasActiveSubscription()`
2. StoreKitManager checks: `currentUser?.godMode == true`
3. If GOD mode → Returns `true` (bypass check)
4. Camera opens without limit validation

### Server-Side Check (Claude Usage)

When calling Claude API:

1. Edge Function calls: `record_claude_usage(company_id, user_id)`
2. Database function checks: `SELECT god_mode FROM users WHERE id = user_id`
3. If GOD mode → Returns `{allowed: true, tier: "GOD MODE"}`
4. Edge Function proxies request to Claude API
5. Analysis completes successfully

---

## Security Notes

⚠️ **IMPORTANT:**
- GOD mode should **ONLY** be enabled for developer/owner accounts
- Never enable for regular users or customers
- Keep the list of GOD mode users minimal
- Audit GOD mode usage if needed

To see who has GOD mode enabled:

```sql
SELECT
    id,
    email,
    first_name,
    last_name,
    is_admin,
    god_mode,
    created_at
FROM users
WHERE god_mode = true;
```

---

## Disabling GOD Mode

To disable GOD mode for an account:

```sql
UPDATE users
SET god_mode = false
WHERE email = 'dschaaf12@me.com';
```

---

## Testing Checklist

After enabling GOD mode, verify:

- [ ] Run SQL to add `god_mode` column
- [ ] Run SQL to enable GOD mode for dschaaf12@me.com
- [ ] Update `record_claude_usage` function with GOD mode check
- [ ] Build and run app
- [ ] Log in with dschaaf12@me.com
- [ ] Create 10 Apple Vision analyses (should all work)
- [ ] Create 5 Claude analyses without subscription (should all work)
- [ ] Check debug logs for "GOD MODE" messages
- [ ] Verify no subscription prompts appear

---

## Your Account Details

**Email:** dschaaf12@me.com
**ID:** 87dc2e71-ec58-4b0a-bbd0-6217cab197e7
**Name:** Dustin Schaaf
**Company:** Balls (123b8ed8-e9ce-49e0-9d54-c353d40d32ad)
**Role:** IT
**Is Admin:** true
**Is Company Admin:** false (you may want to set this to true)

---

## Optional: Make Yourself Company Admin

If you want to test purchase flows, make yourself a company admin:

```sql
UPDATE users
SET is_company_admin = true
WHERE email = 'dschaaf12@me.com';
```

---

## Troubleshooting

### GOD Mode Not Working

1. **Check database:**
   ```sql
   SELECT god_mode FROM users WHERE email = 'dschaaf12@me.com';
   ```
   Should return: `true`

2. **Check app logs:**
   Look for `[HIPAAComplianceManager]` or `[NetworkService]` messages

3. **Verify function updated:**
   ```sql
   SELECT routine_definition
   FROM information_schema.routines
   WHERE routine_name = 'record_claude_usage';
   ```
   Should contain "god_mode" check

4. **Rebuild app:**
   Clean build folder and rebuild to ensure new code is running

---

## Summary

GOD mode gives you unlimited access to all features:
- No subscription required
- No monthly usage limits
- Works on both Apple Vision and Claude
- Server-side and client-side enforcement bypassed

Perfect for development, testing, and demos!
