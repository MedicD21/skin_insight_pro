-- =============================================================================
-- DEBUG: Why Clients Disappeared After Refresh
-- =============================================================================

-- 1. Check if clients exist at all
SELECT COUNT(*) AS total_clients FROM clients;

-- 2. Check clients with their company_id values
SELECT
    id,
    name,
    first_name,
    last_name,
    company_id,
    user_id,
    created_at
FROM clients
ORDER BY created_at DESC
LIMIT 20;

-- 3. Check if company_id values are valid (match companies table)
SELECT
    c.id AS client_id,
    c.name AS client_name,
    c.company_id,
    CASE
        WHEN c.company_id IS NULL THEN 'NULL (no company)'
        WHEN co.id IS NOT NULL THEN '✓ Valid company'
        ELSE '✗ INVALID - company does not exist!'
    END AS company_status,
    co.name AS company_name
FROM clients c
LEFT JOIN companies co ON c.company_id = co.id
ORDER BY c.created_at DESC;

-- 4. Find orphaned clients (company_id set but company doesn't exist)
SELECT
    c.id,
    c.name,
    c.company_id AS invalid_company_id,
    c.user_id
FROM clients c
LEFT JOIN companies co ON c.company_id = co.id
WHERE c.company_id IS NOT NULL
  AND co.id IS NULL;

-- If this returns rows, those clients are "orphaned"

-- 5. Check what companies exist
SELECT
    id,
    name,
    company_code,
    created_at
FROM companies
ORDER BY created_at DESC;

-- 6. Check users and their company associations
SELECT
    u.id,
    u.email,
    u.first_name,
    u.last_name,
    u.company_id,
    c.name AS company_name
FROM users u
LEFT JOIN companies c ON u.company_id = c.id
WHERE u.company_id IS NOT NULL
ORDER BY u.created_at DESC;

-- 7. Test the query that ClientDashboardView uses
-- Replace '<YOUR_COMPANY_ID>' with actual company_id from step 6
SELECT *
FROM clients
WHERE company_id = '<YOUR_COMPANY_ID>'
ORDER BY created_at DESC;

-- =============================================================================
-- FIXES (if needed)
-- =============================================================================

-- FIX 1: If clients have invalid company_id values, set them to NULL
-- (Uncomment and run if step 4 shows orphaned clients)
/*
UPDATE clients
SET company_id = NULL
WHERE company_id IS NOT NULL
  AND company_id NOT IN (SELECT id FROM companies);
*/

-- FIX 2: If clients should belong to a specific company, update them
-- (Uncomment and replace values if needed)
/*
UPDATE clients
SET company_id = '<CORRECT_COMPANY_ID>'
WHERE user_id = '<USER_ID>';
*/

-- FIX 3: If clients have valid user_id but wrong company_id, sync from user
-- (Uncomment to auto-sync company_id from users table)
/*
UPDATE clients c
SET company_id = u.company_id
FROM users u
WHERE c.user_id = u.id
  AND c.company_id IS DISTINCT FROM u.company_id;
*/

-- =============================================================================
