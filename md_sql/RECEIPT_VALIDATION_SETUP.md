# Receipt Validation Edge Function Setup

This document explains how to deploy and configure the receipt validation Edge Function.

## What It Does

The `validate-receipt` Edge Function:
1. Receives App Store receipt data from the iOS app
2. Maps product IDs to subscription tiers
3. Creates or updates `company_plans` records in Supabase
4. Sets subscription start/end dates based on monthly vs annual subscriptions

## Deployment Steps

### 1. Deploy the Function

```bash
cd /Users/dustinschaaf/Desktop/skin_insight_pro
supabase functions deploy validate-receipt
```

### 2. Verify Deployment

Go to: https://supabase.com/dashboard/project/meqrnevrimzvvhmopxrq/functions

You should see `validate-receipt` in the list.

### 3. Test the Function

You can test it with curl:

```bash
curl -X POST \
  'https://meqrnevrimzvvhmopxrq.supabase.co/functions/v1/validate-receipt' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "receipt": "base64_encoded_receipt",
    "company_id": "test-company-id",
    "product_id": "com.skininsightpro.solo.monthly",
    "transaction_id": "test-transaction-123"
  }'
```

## Product ID to Tier Mapping

| Product ID | Tier | Monthly Cap |
|------------|------|-------------|
| com.skininsightpro.solo.monthly | solo | 100 |
| com.skininsightpro.solo.annual | solo | 100 |
| com.skininsightpro.starter.monthly | starter | 400 |
| com.skininsightpro.starter.annual | starter | 400 |
| com.skininsightpro.professional.monthly | professional | 1,500 |
| com.skininsightpro.business.monthly | business | 5,000 |
| com.skininsightpro.enterprise.monthly | enterprise | 15,000 |

## How It Works

1. **App purchases subscription** → StoreKit completes transaction
2. **StoreKitManager calls validateReceipt()** → Sends receipt to NetworkService
3. **NetworkService posts to Edge Function** → `/functions/v1/validate-receipt`
4. **Edge Function validates and updates database** → Creates/updates `company_plans` record
5. **Subscription is now active** → Company can use analyses up to their monthly cap

## Database Schema

The function updates the `company_plans` table:

```sql
CREATE TABLE company_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID REFERENCES companies(id) NOT NULL,
  tier TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  monthly_company_cap INTEGER NOT NULL,
  apple_transaction_id TEXT,
  product_id TEXT,
  started_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

## Future Enhancements

### Production Receipt Validation

In production, you should validate receipts directly with Apple's server-to-server API:

```typescript
// Add this to the Edge Function
async function verifyReceiptWithApple(receipt: string): Promise<boolean> {
  const response = await fetch('https://buy.itunes.apple.com/verifyReceipt', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      'receipt-data': receipt,
      'password': Deno.env.get('APP_STORE_SHARED_SECRET'),
      'exclude-old-transactions': true
    })
  });

  const data = await response.json();
  return data.status === 0;
}
```

Set the shared secret in Supabase:
1. Go to: https://supabase.com/dashboard/project/meqrnevrimzvvhmopxrq/settings/functions
2. Add secret: `APP_STORE_SHARED_SECRET` = (get from App Store Connect)

### Webhook for Subscription Changes

Apple sends server-to-server notifications for:
- Subscription renewals
- Cancellations
- Billing issues
- Refunds

Set up a webhook endpoint to handle these automatically.

## Troubleshooting

### Function not found
- Make sure you've deployed it: `supabase functions deploy validate-receipt`
- Check the Supabase dashboard to verify it's listed

### Database errors
- Verify `company_plans` table exists with correct schema
- Check that `company_id` exists in `companies` table

### Receipt validation fails
- Check logs in Supabase dashboard: Functions → validate-receipt → Logs
- Verify product IDs match exactly what's in App Store Connect
