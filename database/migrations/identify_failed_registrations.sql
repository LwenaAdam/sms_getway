-- Identify and recover failed registration accounts
-- This script finds users who created auth accounts but didn't complete registration

-- =============================================================================
-- PART 1: IDENTIFY FAILED REGISTRATIONS
-- =============================================================================

-- Find auth users without complete profiles
SELECT 
  au.id as auth_user_id,
  au.email,
  au.created_at as auth_created_at,
  au.email_confirmed_at,
  CASE 
    WHEN u.id IS NULL THEN '❌ No user profile'
    ELSE '✅ Has user profile'
  END as user_profile_status,
  CASE 
    WHEN c.id IS NULL THEN '❌ No client/org'
    ELSE '✅ Has client/org'
  END as client_status,
  CASE 
    WHEN t.id IS NULL THEN '❌ No tenant'
    ELSE '✅ Has tenant'
  END as tenant_status,
  c.id as client_id,
  c.name as client_name,
  t.id as tenant_id,
  t.name as tenant_name
FROM auth.users au
LEFT JOIN public.clients c ON c.owner_id = au.id
LEFT JOIN sms_gateway.tenants t ON t.client_id = c.id
LEFT JOIN sms_gateway.users u ON u.id = au.id
WHERE au.created_at > NOW() - INTERVAL '30 days'  -- Check last 30 days
ORDER BY au.created_at DESC;

-- =============================================================================
-- PART 2: DETAILED BREAKDOWN OF INCOMPLETE REGISTRATIONS
-- =============================================================================

-- Count users by registration status
SELECT 
  'Total auth users (last 30 days)' as category,
  COUNT(*) as count
FROM auth.users
WHERE created_at > NOW() - INTERVAL '30 days'

UNION ALL

SELECT 
  'Auth users without client',
  COUNT(*)
FROM auth.users au
LEFT JOIN public.clients c ON c.owner_id = au.id
WHERE au.created_at > NOW() - INTERVAL '30 days'
  AND c.id IS NULL

UNION ALL

SELECT 
  'Auth users without tenant',
  COUNT(*)
FROM auth.users au
LEFT JOIN public.clients c ON c.owner_id = au.id
LEFT JOIN sms_gateway.tenants t ON t.client_id = c.id
WHERE au.created_at > NOW() - INTERVAL '30 days'
  AND t.id IS NULL

UNION ALL

SELECT 
  'Auth users without user profile',
  COUNT(*)
FROM auth.users au
LEFT JOIN sms_gateway.users u ON u.id = au.id
WHERE au.created_at > NOW() - INTERVAL '30 days'
  AND u.id IS NULL

UNION ALL

SELECT 
  'Fully completed registrations',
  COUNT(*)
FROM auth.users au
INNER JOIN public.clients c ON c.owner_id = au.id
INNER JOIN sms_gateway.tenants t ON t.client_id = c.id
INNER JOIN sms_gateway.users u ON u.id = au.id
WHERE au.created_at > NOW() - INTERVAL '30 days';

-- =============================================================================
-- PART 3: SPECIFIC FAILED USERS (Ready for Recovery)
-- =============================================================================

-- List specific users who need recovery
WITH failed_users AS (
  SELECT 
    au.id as user_id,
    au.email,
    au.created_at,
    COALESCE(au.raw_user_meta_data->>'full_name', 
             au.raw_user_meta_data->>'name',
             SPLIT_PART(au.email, '@', 1)) as name,
    COALESCE(au.raw_user_meta_data->>'phone', 
             au.raw_user_meta_data->>'phone_number', '') as phone,
    c.id as client_id,
    c.name as org_name,
    c.slug as org_slug,
    t.id as tenant_id
  FROM auth.users au
  LEFT JOIN public.clients c ON c.owner_id = au.id
  LEFT JOIN sms_gateway.tenants t ON t.client_id = c.id
  LEFT JOIN sms_gateway.users u ON u.id = au.id
  WHERE au.created_at > NOW() - INTERVAL '30 days'
    AND u.id IS NULL  -- No user profile means incomplete registration
)
SELECT 
  user_id,
  email,
  name,
  phone,
  CASE 
    WHEN client_id IS NULL THEN 'Need to create: Client'
    WHEN tenant_id IS NULL THEN 'Need to create: Tenant'
    ELSE 'Need to create: User profile, tenant_members, settings'
  END as recovery_needed,
  client_id,
  org_name,
  org_slug,
  tenant_id,
  created_at
FROM failed_users
ORDER BY created_at DESC;

-- =============================================================================
-- IMPORTANT: Run this query first to see who needs recovery!
-- Then use the recovery script below for each user
-- =============================================================================
