# Implementation Guide - Remaining Work

This document provides detailed implementation steps for remaining tasks after completing initial fixes.

---

## ✅ COMPLETED ITEMS

### 1. Fixed products.company_id errors
**What was done:**
- Removed the `fetchProductsByCompanyId()` function that queried non-existent `products.company_id` column
- Simplified product fetching to use `fetchProductsByCompanyUsers()` which correctly queries products by `user_id`
- **Files changed:** [NetworkService.swift:1709-1724](Sources/NetworkService.swift#L1709-L1724)

**Testing:**
```swift
// The app now fetches products by:
// 1. Getting all users in the company
// 2. Fetching products where user_id is in that list
// This correctly shares products across company members
```

### 2. Verified Edge Function auth settings
**What was confirmed:**
- `verify_jwt = false` is set in both `supabase/config.toml` and `supabase/functions/claude-analyze/config.toml`
- Function manually validates JWT with token expiration checking
- No debug logging present
- **Deploy command:** `supabase functions deploy claude-analyze --project-ref meqrnevrimzvvhmopxrq --no-verify-jwt`

### 3. Usage UI Polish
**What was done:**
- Added "Units = analyses" label under "AI Usage (Claude)" heading
- **Files changed:** [CompanyProfileView.swift:185-239](Sources/CompanyProfileView.swift#L185-L239)

---

## 📋 REMAINING WORK

### 3. Usage Cap Lifecycle

**Current state:**
- The Edge Function calls `record_claude_usage` RPC function with `p_company_id` and `p_user_id`
- This function exists in Supabase but is not in the repo (needs to be exported or documented)

**Required SQL Function (to verify/create in Supabase Dashboard):**

```sql
-- Navigate to: Supabase Dashboard → SQL Editor
-- Run this to verify the function respects started_at/ends_at

-- First, check if the function exists:
SELECT proname, prosrc
FROM pg_proc
WHERE proname = 'record_claude_usage';

-- Expected function signature:
CREATE OR REPLACE FUNCTION record_claude_usage(
  p_company_id UUID,
  p_user_id UUID
) RETURNS JSON AS $$
DECLARE
  v_plan_id UUID;
  v_started_at TIMESTAMPTZ;
  v_ends_at TIMESTAMPTZ;
  v_company_cap INT;
  v_user_cap INT;
  v_company_usage INT;
  v_user_usage INT;
  v_allowed BOOLEAN := false;
BEGIN
  -- Get active plan for company
  SELECT plan_id, started_at, ends_at
  INTO v_plan_id, v_started_at, v_ends_at
  FROM company_plans
  WHERE company_id = p_company_id
    AND NOW() BETWEEN started_at AND ends_at  -- CRITICAL: Check date range
  LIMIT 1;

  IF v_plan_id IS NULL THEN
    RETURN json_build_object(
      'allowed', false,
      'reason', 'No active plan'
    );
  END IF;

  -- Get plan caps
  SELECT monthly_company_cap, monthly_user_cap
  INTO v_company_cap, v_user_cap
  FROM plans
  WHERE id = v_plan_id;

  -- Count usage in current period (between started_at and ends_at)
  SELECT COUNT(*)
  INTO v_company_usage
  FROM ai_usage_events
  WHERE company_id = p_company_id
    AND created_at BETWEEN v_started_at AND v_ends_at
    AND provider = 'claude';

  SELECT COUNT(*)
  INTO v_user_usage
  FROM ai_usage_events
  WHERE user_id = p_user_id
    AND created_at BETWEEN v_started_at AND v_ends_at
    AND provider = 'claude';

  -- Check if allowed
  v_allowed := (v_company_usage < v_company_cap)
    AND (v_user_usage < v_user_cap);

  -- If allowed, insert usage event
  IF v_allowed THEN
    INSERT INTO ai_usage_events (company_id, user_id, provider, created_at)
    VALUES (p_company_id, p_user_id, 'claude', NOW());
  END IF;

  RETURN json_build_object(
    'allowed', v_allowed,
    'company_usage', v_company_usage,
    'company_cap', v_company_cap,
    'user_usage', v_user_usage,
    'user_cap', v_user_cap,
    'plan_period_start', v_started_at,
    'plan_period_end', v_ends_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Monthly Plan Rollover:**

Option A - Manual update (simplest):
```sql
-- Run this monthly to extend plans:
UPDATE company_plans
SET started_at = ends_at,
    ends_at = ends_at + INTERVAL '1 month'
WHERE ends_at < NOW() + INTERVAL '7 days'  -- Give 7 day warning window
  AND company_id IN (
    -- Only extend paid companies
    SELECT company_id FROM company_plans
    WHERE plan_id IN (SELECT id FROM plans WHERE price_company > 0)
  );
```

Option B - Automated pg_cron job:
```sql
-- Install pg_cron extension first
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule monthly rollover (runs on 1st of each month at 00:00 UTC)
SELECT cron.schedule(
  'monthly-plan-rollover',
  '0 0 1 * *',
  $$
  UPDATE company_plans
  SET started_at = ends_at,
      ends_at = ends_at + INTERVAL '1 month'
  WHERE ends_at < NOW()
    AND company_id IN (
      SELECT company_id FROM company_plans cp
      JOIN plans p ON cp.plan_id = p.id
      WHERE p.price_company > 0
    );
  $$
);
```

**Testing:**
```sql
-- Test 1: Check usage within date range
SELECT * FROM company_plans WHERE company_id = '<test-company-id>';
SELECT record_claude_usage('<company-id>', '<user-id>');

-- Test 2: Verify usage is counted correctly
SELECT COUNT(*) FROM ai_usage_events
WHERE company_id = '<company-id>'
  AND created_at BETWEEN (SELECT started_at FROM company_plans WHERE company_id = '<company-id>')
                      AND (SELECT ends_at FROM company_plans WHERE company_id = '<company-id>');

-- Test 3: Test expired plan (should reject)
UPDATE company_plans SET ends_at = NOW() - INTERVAL '1 day' WHERE company_id = '<test-company-id>';
SELECT record_claude_usage('<company-id>', '<user-id>');  -- Should return allowed=false
```

---

### 4. Monetization + IAP Setup

**Overview:**
Implement StoreKit 2 for iOS in-app purchases tied to company subscription plans.

**Step 1: Define IAP Products in App Store Connect**

Navigate to App Store Connect → Your App → In-App Purchases → Create

| Product ID | Type | Name | Price | Plan Mapping |
|------------|------|------|-------|--------------|
| `skininsight.low.monthly` | Auto-Renewable Subscription | Low Use Monthly | $49/mo | Low Use plan |
| `skininsight.low.annual` | Auto-Renewable Subscription | Low Use Annual | $490/yr | Low Use plan |
| `skininsight.medium.monthly` | Auto-Renewable Subscription | Medium Use Monthly | $149/mo | Medium Use plan |
| `skininsight.medium.annual` | Auto-Renewable Subscription | Medium Use Annual | $1490/yr | Medium Use plan |
| `skininsight.high.monthly` | Auto-Renewable Subscription | High Use Monthly | $399/mo | High Use plan |
| `skininsight.high.annual` | Auto-Renewable Subscription | High Use Annual | $3990/yr | High Use plan |

Add per-user pricing separately if needed or include in company plan description.

**Step 2: Create StoreKit Manager**

Create new file: `Sources/StoreKitManager.swift`

```swift
import StoreKit
import Foundation

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published var errorMessage: String?

    private var updateListenerTask: Task<Void, Error>?

    private let productIDs = [
        "skininsight.low.monthly",
        "skininsight.low.annual",
        "skininsight.medium.monthly",
        "skininsight.medium.annual",
        "skininsight.high.monthly",
        "skininsight.high.annual"
    ]

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            errorMessage = "Failed to load products: \\(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()

            // Sync to Supabase
            await syncPurchaseToSupabase(transaction: transaction)

            return transaction

        case .userCancelled, .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Failed to restore purchases: \\(error.localizedDescription)"
        }
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }

        purchasedProductIDs = purchased
    }

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }

                await self.syncPurchaseToSupabase(transaction: transaction)
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func syncPurchaseToSupabase(transaction: Transaction) async {
        guard let user = AuthenticationManager.shared.currentUser,
              let userId = user.id,
              let companyId = user.companyId else {
            return
        }

        // Map product ID to plan_id
        let planName = mapProductToPlan(transaction.productID)

        // Call Supabase to update company_plans
        do {
            try await NetworkService.shared.updateCompanyPlan(
                companyId: companyId,
                planName: planName,
                productId: transaction.productID,
                transactionId: String(transaction.id),
                purchaseDate: transaction.purchaseDate,
                expirationDate: transaction.expirationDate
            )
        } catch {
            print("Failed to sync purchase to Supabase: \\(error)")
        }
    }

    private func mapProductToPlan(_ productID: String) -> String {
        if productID.contains("low") {
            return "low"
        } else if productID.contains("medium") {
            return "medium"
        } else if productID.contains("high") {
            return "high"
        }
        return "free"
    }
}

enum StoreError: Error {
    case failedVerification
}
```

**Step 3: Add NetworkService method**

Add to [NetworkService.swift](Sources/NetworkService.swift):

```swift
func updateCompanyPlan(
    companyId: String,
    planName: String,
    productId: String,
    transactionId: String,
    purchaseDate: Date,
    expirationDate: Date?
) async throws {
    // Get plan_id from plans table
    var components = URLComponents(string: "\\(AppConstants.supabaseUrl)/rest/v1/plans")!
    components.queryItems = [
        URLQueryItem(name: "name", value: "eq.\\(planName)"),
        URLQueryItem(name: "select", value: "id")
    ]

    guard let url = components.url else {
        throw NetworkError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    for (key, value) in supabaseHeaders(authenticated: true) {
        request.setValue(value, forHTTPHeaderField: key)
    }

    let (data, _) = try await session.data(for: request)
    let plans = try JSONDecoder().decode([Plan].self, from: data)

    guard let planId = plans.first?.id else {
        throw NetworkError.custom("Plan not found")
    }

    // Upsert company_plans
    let updateUrl = URL(string: "\\(AppConstants.supabaseUrl)/rest/v1/company_plans")!
    var updateRequest = URLRequest(url: updateUrl)
    updateRequest.httpMethod = "POST"
    for (key, value) in supabaseHeaders(authenticated: true) {
        updateRequest.setValue(value, forHTTPHeaderField: key)
    }
    updateRequest.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

    let endsAt = expirationDate ?? Calendar.current.date(byAdding: .month, value: 1, to: purchaseDate)!

    let payload: [String: Any] = [
        "company_id": companyId,
        "plan_id": planId,
        "started_at": ISO8601DateFormatter().string(from: purchaseDate),
        "ends_at": ISO8601DateFormatter().string(from: endsAt),
        "iap_product_id": productId,
        "iap_transaction_id": transactionId
    ]

    updateRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (_, response) = try await session.data(for: updateRequest)
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
    }
}

struct Plan: Codable {
    let id: String
    let name: String
}
```

**Step 4: Create Subscription UI**

Create new file: `Sources/SubscriptionView.swift`

```swift
import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var storeManager = StoreKitManager.shared
    @Environment(\\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(storeManager.products, id: \\.id) { product in
                        SubscriptionCard(product: product)
                    }
                }
                .padding()
            }
            .navigationTitle("Upgrade Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Restore") {
                        Task {
                            await storeManager.restorePurchases()
                        }
                    }
                }
            }
        }
    }
}

struct SubscriptionCard: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var storeManager = StoreKitManager.shared
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(product.displayName)
                .font(.system(size: 20, weight: .bold))

            Text(product.description)
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)

            Text(product.displayPrice)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.accent)

            Button(action: {
                Task {
                    try? await storeManager.purchase(product)
                }
            }) {
                Text("Subscribe")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

**Step 5: Add Upgrade Button to CompanyProfileView**

In [CompanyProfileView.swift](Sources/CompanyProfileView.swift), add:

```swift
@State private var showSubscription = false

// Add to usageSection, after the VStack containing usage rows:
Button(action: { showSubscription = true }) {
    Text("Upgrade Plan")
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(theme.accent)
}
.padding(.top, 8)

// Add to body:
.sheet(isPresented: $showSubscription) {
    SubscriptionView()
}
```

**Step 6: Database Schema Updates**

```sql
-- Add IAP columns to company_plans table
ALTER TABLE company_plans
ADD COLUMN IF NOT EXISTS iap_product_id TEXT,
ADD COLUMN IF NOT EXISTS iap_transaction_id TEXT,
ADD COLUMN IF NOT EXISTS iap_original_transaction_id TEXT,
ADD COLUMN IF NOT EXISTS iap_receipt_data TEXT;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_company_plans_iap_transaction
ON company_plans(iap_transaction_id);
```

---

### 5. Tracking for Monetization

**Step 1: Create IAP Events Table**

```sql
-- Create table to log all IAP events
CREATE TABLE IF NOT EXISTS iap_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id),
    user_id UUID REFERENCES users(id),
    event_type TEXT NOT NULL,  -- 'purchase', 'renewal', 'cancel', 'refund', 'restore'
    product_id TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    original_transaction_id TEXT,
    purchase_date TIMESTAMPTZ,
    expiration_date TIMESTAMPTZ,
    cancellation_date TIMESTAMPTZ,
    amount DECIMAL(10, 2),
    currency TEXT,
    raw_receipt JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_iap_events_company ON iap_events(company_id);
CREATE INDEX idx_iap_events_user ON iap_events(user_id);
CREATE INDEX idx_iap_events_transaction ON iap_events(transaction_id);
CREATE INDEX idx_iap_events_type ON iap_events(event_type);
CREATE INDEX idx_iap_events_created ON iap_events(created_at DESC);
```

**Step 2: Update StoreKitManager to Log Events**

Add to `StoreKitManager.swift`:

```swift
private func logIAPEvent(
    type: String,
    transaction: Transaction
) async {
    guard let user = AuthenticationManager.shared.currentUser,
          let userId = user.id,
          let companyId = user.companyId else {
        return
    }

    try? await NetworkService.shared.logIAPEvent(
        companyId: companyId,
        userId: userId,
        eventType: type,
        productId: transaction.productID,
        transactionId: String(transaction.id),
        originalTransactionId: String(transaction.originalID),
        purchaseDate: transaction.purchaseDate,
        expirationDate: transaction.expirationDate
    )
}

// Call this in purchase() and listenForTransactions()
await logIAPEvent(type: "purchase", transaction: transaction)
```

**Step 3: Add NetworkService Method**

```swift
func logIAPEvent(
    companyId: String,
    userId: String,
    eventType: String,
    productId: String,
    transactionId: String,
    originalTransactionId: String,
    purchaseDate: Date,
    expirationDate: Date?
) async throws {
    let url = URL(string: "\\(AppConstants.supabaseUrl)/rest/v1/iap_events")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    for (key, value) in supabaseHeaders(authenticated: true) {
        request.setValue(value, forHTTPHeaderField: key)
    }

    let payload: [String: Any] = [
        "company_id": companyId,
        "user_id": userId,
        "event_type": eventType,
        "product_id": productId,
        "transaction_id": transactionId,
        "original_transaction_id": originalTransactionId,
        "purchase_date": ISO8601DateFormatter().string(from: purchaseDate),
        "expiration_date": expirationDate.map { ISO8601DateFormatter().string(from: $0) } as Any
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (_, _) = try await session.data(for: request)
}
```

**Step 4: Add Billing Status to CompanyProfileView**

Add after `usageSection`:

```swift
@State private var currentPlan: String?
@State private var planExpirationDate: Date?

private var billingStatusSection: some View {
    VStack(alignment: .leading, spacing: 16) {
        Text("Billing Status")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(theme.primaryText)

        VStack(spacing: 12) {
            HStack {
                Text("Current Plan:")
                    .foregroundColor(theme.secondaryText)
                Spacer()
                Text(currentPlan ?? "Free")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }

            if let expirationDate = planExpirationDate {
                Divider()
                HStack {
                    Text("Renewal Date:")
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                    Text(expirationDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                }
            }
        }
        .padding(16)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// Add fetch function
private func loadBillingStatus() async {
    guard let companyId = authManager.currentUser?.companyId else { return }

    do {
        let plan = try await NetworkService.shared.fetchCompanyPlan(companyId: companyId)
        currentPlan = plan.planName
        planExpirationDate = plan.endsAt
    } catch {
        print("Failed to load billing status")
    }
}

// Call in .task
.task {
    await loadCompany()
    await loadUsageCounts()
    await loadBillingStatus()
}
```

**Step 5: Admin Billing Dashboard (Optional)**

Create `Sources/AdminBillingView.swift`:

```swift
struct AdminBillingView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var companies: [CompanyBilling] = []

    var body: some View {
        List(companies) { company in
            VStack(alignment: .leading) {
                Text(company.name)
                    .font(.headline)
                Text("Plan: \\(company.planName) | Usage: \\(company.usage)/\\(company.cap)")
                    .font(.caption)
                Text("Renewal: \\(company.renewalDate.formatted())")
                    .font(.caption)
            }
        }
        .navigationTitle("Billing Overview")
        .task {
            await loadCompanies()
        }
    }

    private func loadCompanies() async {
        // Fetch all companies with plan and usage data
    }
}

struct CompanyBilling: Identifiable {
    let id: String
    let name: String
    let planName: String
    let usage: Int
    let cap: Int
    let renewalDate: Date
}
```

---

### 7. Test Coverage / Validation

**Test Plan:**

#### A. Claude + Apple Fallback Flow

**Test 1: Expired Token**
```swift
// 1. Manually expire token in app
// 2. Attempt to analyze image
// 3. Verify:
//    - Edge function returns 401
//    - App falls back to Apple Vision
//    - User sees "Using Apple Vision (offline mode)" message
```

**Test 2: Over Limit - Company Cap**
```sql
-- Manually set company usage to cap
UPDATE company_plans SET started_at = NOW() - INTERVAL '15 days' WHERE company_id = '<test-id>';

-- Use app to max out usage
-- Next request should:
-- - Return 402 from edge function
-- - Fall back to Apple Vision
-- - Show upgrade prompt
```

**Test 3: Over Limit - User Cap**
```sql
-- Similar to above but for user cap
```

#### B. AI Usage Events Consistency

**Test 1: Both Counters Increment**
```sql
-- Before analysis:
SELECT COUNT(*) FROM ai_usage_events WHERE company_id = '<id>' AND provider = 'claude';
SELECT COUNT(*) FROM ai_usage_events WHERE user_id = '<user-id>' AND provider = 'claude';

-- Perform analysis

-- After analysis:
-- Both counts should increment by 1
```

**Test 2: Usage Respects Date Range**
```sql
-- Set plan started_at to 10 days ago
UPDATE company_plans SET started_at = NOW() - INTERVAL '10 days', ends_at = NOW() + INTERVAL '20 days';

-- Old usage should not count
INSERT INTO ai_usage_events (company_id, user_id, provider, created_at)
VALUES ('<company-id>', '<user-id>', 'claude', NOW() - INTERVAL '15 days');

-- Run analysis - should be allowed
SELECT record_claude_usage('<company-id>', '<user-id>');
```

#### C. IAP Flows

**Test 1: New Purchase**
```swift
// 1. Start with free plan
// 2. Purchase Low Use Monthly
// 3. Verify:
//    - Transaction completes
//    - company_plans updated with plan_id, dates
//    - iap_events logged
//    - CompanyProfileView shows new plan
```

**Test 2: Restore Purchase**
```swift
// 1. Delete app
// 2. Reinstall
// 3. Login
// 4. Tap "Restore Purchases"
// 5. Verify plan is restored
```

**Test 3: Upgrade**
```swift
// 1. Have Low Use plan
// 2. Purchase Medium Use plan
// 3. Verify:
//    - Old subscription cancelled
//    - New plan active
//    - Proration applied (if supported)
```

**Test 4: Expiry**
```swift
// 1. Cancel subscription in App Store
// 2. Wait for expiration
// 3. Verify:
//    - Plan reverts to Free
//    - Claude requests blocked
```

---

## 🎯 Summary

**Completed:**
1. ✅ Fixed products.company_id errors
2. ✅ Verified Edge Function auth settings
3. ✅ Added "Units = analyses" label to usage UI

**Requires Supabase Dashboard Work:**
- Verify/create `record_claude_usage` function with date range checking
- Set up monthly plan rollover (manual or pg_cron)
- Create `iap_events` table
- Add IAP columns to `company_plans`

**Requires Swift Code:**
- Create `StoreKitManager.swift`
- Create `SubscriptionView.swift`
- Add NetworkService methods for IAP
- Add billing status section to CompanyProfileView
- Implement comprehensive testing

**Testing Checklist:**
- [ ] Expired token falls back to Apple Vision
- [ ] Company cap enforced
- [ ] User cap enforced
- [ ] Both usage counters increment
- [ ] Date range filtering works
- [ ] New purchase flow
- [ ] Restore purchases
- [ ] Upgrade/downgrade
- [ ] Subscription expiry

