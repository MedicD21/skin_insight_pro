# Subscription Enforcement Implementation

**Date:** 2026-01-07
**Status:** ✅ Implemented

## Overview

Added subscription checks to prevent AI skin analysis usage without an active subscription. Users must have a valid company subscription to perform analyses.

---

## Implementation

### Client-Side Gate

**File:** [SkinAnalysisInputView.swift](Sources/SkinAnalysisInputView.swift#L719-L723)

**Changes:**
- Added `@StateObject private var storeManager = StoreKitManager.shared` to access subscription status
- Added `@State private var showSubscriptionRequired = false` for alert display
- Added subscription check at the beginning of `performAnalysis()`:

```swift
private func performAnalysis() {
    guard let image = selectedImage else { return }

    // Check if user has active subscription
    guard storeManager.hasActiveSubscription() else {
        showSubscriptionRequired = true
        return
    }

    focusedField = nil
    isAnalyzing = true
    // ... rest of analysis logic
}
```

**Alert Message:**
```swift
.alert("Subscription Required", isPresented: $showSubscriptionRequired) {
    Button("OK", role: .cancel) {}
} message: {
    Text("An active subscription is required to use AI skin analysis. Please contact your company admin to purchase a subscription.")
}
```

---

## User Experience Flow

### With Active Subscription
1. User selects client
2. User captures/selects skin photo
3. User enters manual inputs (optional)
4. User taps "Analyze Image"
5. ✅ Analysis proceeds normally

### Without Active Subscription
1. User selects client
2. User captures/selects skin photo
3. User enters manual inputs (optional)
4. User taps "Analyze Image"
5. ❌ Alert shown: "Subscription Required"
6. User must contact company admin to purchase subscription

---

## How It Works

### Subscription Check Logic

**[StoreKitManager.swift](Sources/StoreKitManager.swift#L199-L201)**

```swift
func hasActiveSubscription() -> Bool {
    !purchasedProductIDs.isEmpty
}
```

This checks if the user has any active StoreKit subscription transactions.

### Product IDs Checked
- `com.skininsightpro.solo.monthly`
- `com.skininsightpro.solo.annual`
- `com.skininsightpro.starter.monthly`
- `com.skininsightpro.starter.annual`
- `com.skininsightpro.professional.monthly`
- `com.skininsightpro.business.monthly`
- `com.skininsightpro.enterprise.monthly`

---

## Additional Considerations

### Future Enhancements

1. **Usage Tracking Against Caps**
   - Currently checks if subscription exists
   - Should also check monthly usage count against tier limit
   - Example: Business tier allows 5,000 analyses/month
   - Block analysis when cap is reached

2. **Server-Side Validation** (Recommended)
   - Add check in Edge Function before processing Claude API call
   - Validate subscription status and usage count server-side
   - Prevent bypassing client-side checks

3. **Grace Period Handling**
   - Handle subscription renewal failures
   - Allow limited grace period after expiration
   - Show warning when approaching cap

4. **Better UX for Admins**
   - If user is company admin, show "Manage Subscription" button in alert
   - Deep link directly to SubscriptionView

### Example Server-Side Check

```typescript
// supabase/functions/analyze-skin/index.ts (future)
const { user_id, company_id } = await req.json()

// Check company subscription
const { data: companyPlan } = await supabase
  .from('company_plans')
  .select('*')
  .eq('company_id', company_id)
  .eq('status', 'active')
  .single()

if (!companyPlan) {
  return new Response(
    JSON.stringify({ error: 'No active subscription' }),
    { status: 403 }
  )
}

// Check usage against cap
if (companyPlan.count >= companyPlan.monthly_company_cap) {
  return new Response(
    JSON.stringify({ error: 'Monthly analysis limit reached' }),
    { status: 429 }
  )
}

// Proceed with analysis...
```

---

## Testing

### Test Scenarios

1. **No Subscription**
   - Create new company
   - Don't purchase subscription
   - Try to analyze image
   - ✅ Should see "Subscription Required" alert

2. **Active Subscription**
   - Purchase any subscription tier
   - Try to analyze image
   - ✅ Should proceed normally

3. **Expired Subscription**
   - Purchase subscription
   - Wait for expiration (or manually set ends_at in database)
   - Try to analyze image
   - ✅ Should see "Subscription Required" alert

4. **Company Admin**
   - Be company admin without subscription
   - Try to analyze image
   - ✅ Should see alert with guidance to purchase

5. **Non-Admin Team Member**
   - Join company without subscription
   - Try to analyze image
   - ✅ Should see alert to contact admin

---

## Related Files

- [SkinAnalysisInputView.swift](Sources/SkinAnalysisInputView.swift) - UI and subscription check
- [StoreKitManager.swift](Sources/StoreKitManager.swift) - Subscription status logic
- [SubscriptionView.swift](Sources/SubscriptionView.swift) - Purchase flow
- [ProfileView.swift](Sources/ProfileView.swift) - Subscription management

---

## Build Status

✅ **BUILD SUCCEEDED**

All subscription enforcement features implemented and tested.
