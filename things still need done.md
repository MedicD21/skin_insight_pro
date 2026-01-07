Things Still Need Done

1) Fix products.company_id errors
   - Current logs show queries against products.company_id, but the column does not exist.
   - Decide on approach:
     - Add company_id to products table, update RLS/policies, and backfill.
     - Or remove company_id-based product queries and rely on user_id only.

2) Verify Edge Function auth settings are stable
   - Confirm claude-analyze is deployed with verify_jwt disabled (Dashboard + deploy command).
   - Once stable, remove any temporary debug logging if no longer needed.

3) Usage cap lifecycle
   - Confirm record_claude_usage respects company_plans.started_at/ends_at as intended.
   - Decide how to roll plans forward monthly (manual update vs. scheduled job).

4) Monetization + IAP setup
   - Define IAP products (monthly/annual, low/medium/high company tiers).
   - Implement StoreKit 2 purchase flow and receipt validation.
   - Map IAP products to plans table (plan_id) and update company_plans on purchase/renewal/cancel.
   - Handle upgrades/downgrades, proration rules, and grace periods.
   - Add restore purchases and account linking to company_id.

5) Tracking for monetization
   - Log IAP events (purchase, renewal, cancel, refund) into a supabase table.
   - Add basic billing status UI in Company Profile (plan, renewal date, payment status).
   - Add admin-only view for usage + billing reconciliation.

6) Usage UI polish (optional)
   - Add a small label like "Units = analyses" under usage counts.
   - Consider showing plan name + caps (company/user) alongside usage.

7) Test coverage / validation
   - Verify Claude + Apple fallback flow on expired tokens and over-limit cases.
   - Confirm ai_usage_events increments for both user and company consistently.
   - Verify IAP flows across new purchase, restore, upgrade, and expiry.
