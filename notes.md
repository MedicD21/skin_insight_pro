supabase password: hrrQzliGqpB0TX6G
supabase url: https://meqrnevrimzvvhmopxrq.supabase.co
supabase pub key: sb_publishable_JYadlrb2j6E_jMlTL-fLsg_SjhuJqrg
supabase secret key: sb_secret_FfS01kWmdWZEVfG3Q3KZsw_ij5bCwVL

## 2025-12-28 - Supabase Auth Integration Complete!

- Fixed invalid API key error by updating AppConstants.swift with correct anon public key
- Completed rewrite to use proper Supabase Auth API (/auth/v1/signup, /auth/v1/token)
- Implemented JWT token management with access/refresh tokens
- Updated RLS policies to use auth.uid() for secure data isolation
- Build successful with no errors or warnings
- Ready to test! See READY_TO_TEST.md for next steps

AI rules still not being applied. I made rule for redness, skin concern after analysis was Redness, the recommendation in the rule was to put a bag over clients head, the recommendation was not applied. also how do we connect products to recommendations? Make a seperate section in the skin analysis for Product recommendations below the normal Recommendations
