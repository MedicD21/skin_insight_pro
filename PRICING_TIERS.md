# SkinInsightPro AI Usage Tiers (Claude)

Effective date: 2026-01-01

This document defines the default Claude usage tiers, pricing, and how to change caps later.

## Tier Structure (Claude + Apple Vision)

Apple Vision is free and on-device. Claude usage is metered and limited by plan.

### Free (Apple Vision Only)
- Price: $0
- Claude analyses: 0 per month
- Notes: Apple Vision only, limited use.

### Low Use
- Price: $49 per company/month + $10 per user/month
- Company cap: 100 Claude analyses/month
- Per-user cap: 20 Claude analyses/month

### Medium Use
- Price: $149 per company/month + $15 per user/month
- Company cap: 500 Claude analyses/month
- Per-user cap: 75 Claude analyses/month

### High Use
- Price: $399 per company/month + $20 per user/month
- Company cap: 2000 Claude analyses/month
- Per-user cap: 250 Claude analyses/month

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
