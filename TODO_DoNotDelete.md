# SkinInsightPro Production Launch TODO

**Last Updated:** 2026-01-07

---

## 🔴 CRITICAL (Must Complete Before Launch)

### 1. App Store & IAP Setup
- [ ] Submit 7 IAP products for review in App Store Connect
  - Add screenshots and descriptions for each tier
  - Submit all products together
  - Approval typically takes 24-48 hours
- [ ] Test sandbox purchases for each pricing tier
  - Create sandbox test account in App Store Connect
  - Test all 7 products (Solo Monthly/Annual, Starter Monthly/Annual, Professional, Business, Enterprise)
  - Verify transactions complete successfully
- [ ] **Deploy `validate-receipt` Edge Function to Supabase**
  - See instructions below
- [ ] Test receipt validation flow end-to-end
  - Purchase in sandbox → Verify `company_plans` record created
  - Check subscription status appears in Profile
  - Verify Claude usage is enabled after purchase

### 2. HIPAA Compliance
- [x] ~~Audit log sync to Supabase implemented~~
- [ ] **Test audit log sync** to verify it's working
  - Perform actions in app (view client, create analysis)
  - Check Supabase `hipaa_audit_logs` table for entries
  - Verify logs sync on background/foreground
- [ ] **Sign BAA with Supabase** ⚠️ LEGAL REQUIREMENT
  - Contact: https://supabase.com/contact/enterprise
  - Enable HIPAA add-on in Supabase project
  - Must be signed before storing real PHI
- [ ] **Sign BAA with Anthropic** (if using Claude)
  - Contact: https://www.anthropic.com/enterprise
  - Required for HIPAA compliance with Claude API
- [ ] **Create HIPAA Privacy Policy document**
  - Required by law for healthcare apps
  - Should cover: data collection, usage, sharing, patient rights
  - Consider hiring HIPAA compliance attorney
- [ ] **Create Breach Notification Plan**
  - Document procedures if data breach occurs
  - Include notification timelines (60 days per HIPAA)
  - Designate responsible parties

### 3. Legal/Privacy Documents
- [ ] Create comprehensive Privacy Policy
  - Cover data collection, cookies, third-party services
  - Include contact information for privacy concerns
  - Must be accessible during app signup
- [ ] Create Terms of Service
  - Define user responsibilities
  - Liability limitations
  - Account termination conditions
- [ ] Add privacy policy acceptance during signup
  - Checkbox with link to policy
  - Store acceptance timestamp in database
- [ ] Document data retention policy
  - Recommend: 7 years per HIPAA requirements
  - Define when data is deleted
  - Backup/archive procedures

### 4. Essential Testing
- [ ] Test complete purchase flow with sandbox account
  - Create company → Purchase subscription → Verify activation
- [ ] Verify Claude usage enforcement works
  - Test with/without subscription
  - Test when monthly cap is reached (402 error handling)
  - Verify fallback to Apple Vision
- [ ] Test Apple Vision free tier limit (5/month)
  - Create account without subscription
  - Perform 5 analyses
  - Verify 6th analysis is blocked with upgrade prompt
- [ ] Test company creation/joining flows
  - Create new company (becomes admin)
  - Join existing company with code
  - Verify admin permissions work correctly
- [ ] Test subscription restore functionality
  - Purchase subscription on device A
  - Sign in on device B
  - Tap "Restore Purchases"
  - Verify subscription appears
- [ ] Test session timeout and HIPAA audit logging
  - Verify 15-minute timeout works
  - Check audit logs for SESSION_TIMEOUT events
  - Test activity resets timer

---

## 🟡 IMPORTANT (Should Complete Soon)

### 5. Production Enhancements
- [ ] Add App Store Server Notifications webhooks
  - Handle automatic renewals
  - Handle cancellations
  - Handle billing issues
  - Update `company_plans` status automatically
  - Reference: https://developer.apple.com/documentation/appstoreservernotifications
- [ ] Implement proper Apple receipt verification
  - Currently: Simplified validation (trusts client)
  - Production: Validate with Apple's API
  - See: [RECEIPT_VALIDATION_SETUP.md](RECEIPT_VALIDATION_SETUP.md)
- [ ] Add deep link to iOS subscription settings
  - Let users manage/cancel subscriptions
  - Use: `https://apps.apple.com/account/subscriptions`
- [ ] Add "Contact Admin" flow for non-admin users
  - Show admin contact info when non-admin wants subscription
  - Email/message functionality

### 6. Security
- [ ] Conduct security risk assessment
  - Review authentication mechanisms
  - Audit data encryption (in-transit and at-rest)
  - Check RLS policies on all tables
  - Review API endpoint security
- [ ] Train staff on HIPAA requirements
  - Document handling procedures
  - Incident response training
  - Password security training
- [ ] Implement 2FA for admin accounts (recommended)
  - Add SMS or TOTP-based 2FA
  - Require for company admins
  - Optional for regular users
- [ ] Consider adding IP address detection to audit logs
  - Currently `ip_address` is always null
  - Could fetch from API service
  - Useful for security monitoring

### 7. Admin Features
- [ ] Create admin dashboard to view audit logs
  - Search/filter by user, event type, date
  - Export to CSV
  - Real-time monitoring
- [ ] Add team usage overview for company admins
  - See which team members are using analyses
  - Monthly usage by user
  - Department/location breakdowns
- [ ] Add ability to export usage reports
  - For billing reconciliation
  - For internal analytics
  - PDF/CSV formats
- [ ] Show billing history
  - Past invoices
  - Payment methods
  - Renewal dates

---

## 🟢 NICE-TO-HAVE (Future Enhancements)

### 8. Analytics & Optimization
- [ ] Track conversion rates (signups → subscriptions)
  - Measure funnel: Sign up → Company setup → Purchase
  - Identify drop-off points
- [ ] Monitor churn rate
  - Track subscription cancellations
  - Exit surveys
  - Win-back campaigns
- [ ] A/B test pricing tiers
  - Test different price points
  - Test messaging/positioning
  - Optimize conversion
- [ ] Add usage warnings when approaching monthly limit
  - Alert at 80% of cap
  - Alert at 90% of cap
  - Prompt to upgrade before hitting limit

### 9. User Experience Improvements
- [ ] Add onboarding tour for new users
  - Highlight key features
  - Show how to create first client
  - Explain AI analysis options
- [ ] Create help/documentation section
  - FAQs
  - Video tutorials
  - Feature guides
- [ ] Add feedback/support system
  - In-app feedback form
  - Bug reporting
  - Feature requests
- [ ] Implement push notifications
  - Subscription renewal reminders
  - Usage limit warnings
  - New feature announcements

---

## 📋 PRIORITY ORDER (What to Do Next)

### Week 1: Edge Functions & Testing
1. ✅ Deploy `validate-receipt` Edge Function (see below)
2. ✅ Test sandbox IAP purchases end-to-end
3. ✅ Test audit log sync to Supabase
4. ✅ Submit IAPs for App Store review

### Week 2: Legal & Compliance
5. Create Privacy Policy and Terms of Service
6. Contact Supabase to sign BAA
7. Contact Anthropic to sign BAA
8. Create Breach Notification Plan document

### Week 3: Final Testing & Launch
9. Complete all testing checklist items
10. Set up App Store Server Notifications
11. Conduct security risk assessment
12. Submit app to App Store for review

---

## 🚀 EDGE FUNCTION DEPLOYMENT INSTRUCTIONS

### Deploy `validate-receipt` Edge Function

**Location:** `supabase/functions/validate-receipt/index.ts`

**Steps:**

1. **Navigate to project directory:**
   ```bash
   cd /Users/dustinschaaf/Desktop/skin_insight_pro
   ```

2. **Deploy the function:**
   ```bash
   supabase functions deploy validate-receipt
   ```

3. **Verify deployment:**
   - Go to: https://supabase.com/dashboard/project/meqrnevrimzvvhmopxrq/functions
   - You should see `validate-receipt` in the list
   - Check logs for any errors

4. **Test the function:**
   ```bash
   curl -X POST \
     'https://meqrnevrimzvvhmopxrq.supabase.co/functions/v1/validate-receipt' \
     -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
     -H 'apikey: YOUR_SUPABASE_ANON_KEY' \
     -H 'Content-Type: application/json' \
     -d '{
       "receipt": "test-receipt-data",
       "company_id": "test-company-id",
       "product_id": "com.skininsightpro.solo.monthly",
       "transaction_id": "test-transaction-123"
     }'
   ```

5. **Check database:**
   ```sql
   SELECT * FROM company_plans ORDER BY created_at DESC LIMIT 1;
   ```

### Deploy `claude-analyze` Edge Function (Already Done)

**Status:** ✅ Already deployed with server-side validation

This function:
- Validates JWT tokens
- Calls `record_claude_usage` to check subscription & limits
- Returns 402 if limit exceeded
- Proxies to Claude API if allowed

---

## 📊 COMPLETION STATUS

**Overall Progress:** ~75% Complete

### Completed ✅
- [x] StoreKit 2 monetization system
- [x] Company onboarding flow
- [x] Subscription UI with 7 pricing tiers
- [x] Receipt validation Edge Function (created, needs deployment)
- [x] Server-side Claude usage validation
- [x] Apple Vision free tier (5/month)
- [x] HIPAA audit logging system
- [x] Audit log sync to Supabase
- [x] Session timeout (15 minutes)
- [x] Client consent with digital signature
- [x] Data export/deletion features
- [x] Password requirements
- [x] All IAP products created in App Store Connect

### In Progress 🟡
- Edge function deployment (validate-receipt)
- Testing phase

### Not Started 🔴
- BAA signing (Supabase & Anthropic)
- Legal documents (Privacy Policy, Terms, Breach Plan)
- App Store submission
- Server webhooks
- Admin dashboard

---

## 📞 IMPORTANT CONTACTS

- **Supabase Enterprise:** https://supabase.com/contact/enterprise
- **Anthropic Enterprise:** https://www.anthropic.com/enterprise
- **HIPAA Compliance Attorney:** (Find one for legal docs)
- **App Store Connect:** https://appstoreconnect.apple.com

---

## ⚠️ BLOCKERS

**Cannot launch without:**
1. Signed BAA with Supabase (legal requirement for PHI)
2. Privacy Policy (legal requirement for App Store)
3. IAPs approved by Apple (required for monetization)

**Should not launch without:**
1. Comprehensive testing of all features
2. Edge functions deployed and tested
3. Security risk assessment completed

---

## 💡 NOTES

- All code is complete and builds successfully
- Database schema is up to date
- Edge functions are written, just need deployment
- Focus is now on deployment, testing, and legal compliance
- Estimated time to production: 2-3 weeks with proper testing

---

**Next Immediate Action:** Deploy the `validate-receipt` Edge Function following the instructions above.
