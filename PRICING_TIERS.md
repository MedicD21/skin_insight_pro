# SkinInsightPro Pricing Tiers

Effective date: 2026-01-07

This document defines the subscription tiers, pricing, and usage limits.

## Tier Structure

All plans include Apple Vision (on-device, free) + Claude AI analysis (cloud-based, metered).

### Solo
- **Price**: $29/month
- **Monthly analyses**: 100
- **Best for**: Individual practitioners, solo estheticians
- **Cost per analysis**: ~$0.29

### Starter
- **Price**: $79/month
- **Monthly analyses**: 400
- **Best for**: Small practices (1-2 providers)
- **Cost per analysis**: ~$0.20

### Professional
- **Price**: $199/month
- **Monthly analyses**: 1,500
- **Best for**: Growing practices (2-4 providers)
- **Cost per analysis**: ~$0.13

### Business
- **Price**: $499/month
- **Monthly analyses**: 5,000
- **Best for**: Multi-location practices (4-6 locations)
- **Cost per analysis**: ~$0.10

### Enterprise
- **Price**: $999/month
- **Monthly analyses**: 15,000
- **Best for**: Large operations (7+ locations)
- **Cost per analysis**: ~$0.07

## How Caps Are Enforced

- Company cap is the primary limiter to protect overall costs.
- Per-user cap prevents a single user from consuming the full company quota.
- If a company hits its cap, Claude requests are blocked and the app should fall back to Apple Vision (or show a paywall/upgrade prompt).

## How to Change Caps or Prices

1) Update the tier definitions where you store plan settings (recommended: a `plans` table in Supabase).
   - Fields to update:
     - `monthly_company_cap`
     - `monthly_user_cap`
     - `price_company`
     - `price_per_user`

2) Update any app UI text that displays plan prices or caps.
   - Example: pricing screen, upgrade prompt, or admin settings.

3) If you use a cache or hardcoded defaults, update those values too.
   - Example: constants in the app or server logic.

4) Verify changes:
   - Simulate usage at 80% and 100% of caps.
   - Confirm the UI shows the correct remaining allowance.
   - Ensure Claude calls are blocked after caps are reached.

## Notes

- Pricing is a starting point and can be adjusted based on actual Claude costs and customer usage.
- You can also offer add-on credit packs if a customer exceeds their caps.
