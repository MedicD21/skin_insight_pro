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
