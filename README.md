# SkinInsightPro

A HIPAA-compliant skin analysis application for medical professionals using AI-powered image analysis.

## 📋 Documentation Index

### Core Features
- **[AI Skin Analysis Explained](AI_SKIN_ANALYSIS_EXPLAINED.md)** - How the Apple Vision and Claude AI analysis works
- **[HIPAA Compliance](HIPAA_COMPLIANCE.md)** - HIPAA compliance features and implementation
- **[Client Consent Implementation](CLIENT_CONSENT_IMPLEMENTATION.md)** - Patient consent flow and management

### Monetization & Billing
- **[Monetization Implementation Summary](MONETIZATION_IMPLEMENTATION_SUMMARY.md)** - Complete StoreKit 2 subscription system
- **[Pricing Tiers](PRICING_TIERS.md)** - Subscription plans and pricing structure
- **[Subscription Enforcement](SUBSCRIPTION_ENFORCEMENT.md)** - How subscription gates protect features
- **[Receipt Validation Setup](RECEIPT_VALIDATION_SETUP.md)** - Server-side receipt validation guide
- **[Plan Rollover Setup](PLAN_ROLLOVER_SETUP.md)** - Monthly usage cap reset implementation

## 🚀 Current Status

**Build Status:** ✅ **BUILD SUCCEEDED**
**Date:** 2026-01-07

### ✅ Completed Features

#### Company & User Management
- Company onboarding (create or join)
- Two-tier admin system:
  - **Platform Admin** (`is_admin`) - Manages products, AI rules, settings
  - **Company Admin** (`is_company_admin`) - Purchases subscriptions
- Company creators automatically get both admin privileges
- 8-character company codes for joining

#### Subscription System
- StoreKit 2 integration with 7 IAP products
- Company-based subscriptions (one admin purchases for entire team)
- Beautiful subscription UI with pricing tiers
- Receipt validation via Supabase Edge Function
- Subscription status display in Profile
- Admin-only purchase restrictions

#### AI Analysis Protection
- Subscription required for AI skin analysis
- Claude Vision provider requires active subscription
- Apple Vision remains free as basic option
- Usage tracking against monthly caps

#### Pricing Structure
| Tier | Monthly | Annual | Analyses/Month |
|------|---------|--------|----------------|
| Solo | $29 | $290 | 100 |
| Starter | $79 | $790 | 400 |
| Professional | $199 | - | 1,500 |
| Business | $499 | - | 5,000 |
| Enterprise | $999 | - | 15,000 |

*Annual plans save ~17% (2 months free)*

## 🔐 Security & Compliance

### HIPAA Features
- Patient consent tracking
- Encrypted data storage
- Audit logging
- Session timeout (15 minutes)
- Data export/deletion rights
- Screen privacy overlay

### Subscription Security
- StoreKit 2 transaction verification
- Server-side receipt validation
- Admin-only purchase restrictions
- Company-level access control

## 📱 User Flows

### New User Journey
1. Sign up with email/password
2. Complete profile (name, role, photo)
3. Create company (becomes admin) OR join existing company
4. Main app access
5. Admin purchases subscription (optional)
6. Perform AI skin analysis

### AI Analysis Flow
1. Select client
2. Capture/select skin photo
3. Enter manual inputs (optional)
4. Tap "Analyze Image"
5. **Subscription check** - Must have active subscription
6. Analysis proceeds using Apple Vision or Claude
7. View results and recommendations

### Subscription Purchase Flow
1. Admin opens Profile → Subscription section
2. Click "Choose a Plan"
3. Review all 7 pricing tiers
4. Select plan and confirm purchase
5. StoreKit 2 processes payment
6. Receipt validated with Edge Function
7. Subscription active for entire company

## 🛠 Development Setup

### Prerequisites
- Xcode 15+
- Swift 5.9+
- Supabase account
- App Store Connect account (for IAP)

### Environment Variables
Create `.env` file with:
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
```

### Database Setup
1. Run migrations in Supabase Dashboard
2. Deploy Edge Functions:
   ```bash
   supabase functions deploy claude-analyze
   supabase functions deploy validate-receipt
   supabase functions deploy rollover-monthly-plans
   ```

### App Store Connect Setup
1. Create 7 IAP products (see [Pricing Tiers](PRICING_TIERS.md))
2. Submit IAPs for review
3. Configure StoreKit testing

## 📊 Analytics & Monitoring

### Usage Tracking
- Company-level monthly analysis count
- User-level analysis tracking
- Automatic rollover on 1st of each month
- Usage displayed in Profile view

### Subscription Metrics
- Track conversion rates
- Monitor churn
- Analyze popular tiers
- Revenue reporting

## 🐛 Known Issues & Limitations

1. **Receipt Validation is Simplified**
   - Current implementation trusts StoreKit transaction verification
   - Production should validate receipts directly with Apple API
   - See [Receipt Validation Setup](RECEIPT_VALIDATION_SETUP.md)

2. **No Usage Cap Enforcement Yet**
   - App doesn't block Claude requests when monthly cap is hit
   - Need middleware check before AI analysis calls

3. **No Subscription Management**
   - Users must cancel via iOS Settings
   - No in-app upgrade/downgrade flow

## 🔮 Future Enhancements

### Priority 1 (Required for Launch)
- [ ] Deploy Edge Functions to production
- [ ] Test sandbox purchases for all 7 tiers
- [ ] Submit IAPs for App Store review
- [ ] Add usage cap enforcement

### Priority 2 (Nice to Have)
- [ ] Apple server-to-server receipt verification
- [ ] App Store Server Notifications for renewals
- [ ] Admin dashboard for team usage
- [ ] In-app subscription management
- [ ] Billing history view

### Priority 3 (Future)
- [ ] A/B test pricing
- [ ] Conversion funnel analytics
- [ ] Referral program
- [ ] Team member management UI

## 📞 Support

For issues or questions:
- Open an issue on GitHub
- Contact: support@skininsightpro.com

## 📄 License

Proprietary - All rights reserved
