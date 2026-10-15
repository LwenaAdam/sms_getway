-- Direct recovery without loops - using INSERT INTO ... SELECT
-- This avoids the DO $$ block context issues entirely

-- Step 1: Get the product ID
DO $$
DECLARE v_product_id UUID;
BEGIN
  SELECT id INTO v_product_id FROM public.products WHERE schema_name = 'sms_gateway' LIMIT 1;
  RAISE NOTICE 'Product ID: %', v_product_id;
END $$;

-- Step 2: Create tenants for incomplete users
WITH incomplete_users AS (
  SELECT 
    au.id as user_id,
    au.email,
    c.id as client_id,
    c.name as client_name,
    c.slug as client_slug
  FROM auth.users au
  JOIN public.clients c ON c.owner_id = au.id
  LEFT JOIN sms_gateway.users u ON u.id = au.id
  WHERE u.id IS NULL 
    AND au.created_at > NOW() - INTERVAL '90 days'
)
INSERT INTO sms_gateway.tenants (name, slug, client_id, status)
SELECT 
  client_name,
  client_slug || '-' || substring(user_id::text, 1, 8),
  client_id,
  'active'
FROM incomplete_users
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
RETURNING id, name, slug;

-- Step 3: Create user profiles
WITH incomplete_users AS (
  SELECT 
    au.id as user_id,
    au.email,
    c.id as client_id,
    c.slug as client_slug
  FROM auth.users au
  JOIN public.clients c ON c.owner_id = au.id
  LEFT JOIN sms_gateway.users u ON u.id = au.id
  WHERE u.id IS NULL 
    AND au.created_at > NOW() - INTERVAL '90 days'
),
user_tenants AS (
  SELECT 
    iu.user_id,
    iu.email,
    t.id as tenant_id
  FROM incomplete_users iu
  JOIN sms_gateway.tenants t ON t.slug = iu.client_slug || '-' || substring(iu.user_id::text, 1, 8)
)
INSERT INTO sms_gateway.users (id, email, name, role, tenant_id)
SELECT 
  user_id,
  email,
  SPLIT_PART(email, '@', 1),
  'owner',
  tenant_id
FROM user_tenants
RETURNING id, email, tenant_id;

-- Step 4: Create tenant memberships
WITH incomplete_users AS (
  SELECT 
    au.id as user_id,
    c.slug as client_slug
  FROM auth.users au
  JOIN public.clients c ON c.owner_id = au.id
  JOIN sms_gateway.users u ON u.id = au.id
  LEFT JOIN sms_gateway.tenant_members tm ON tm.user_id = au.id
  WHERE tm.user_id IS NULL 
    AND au.created_at > NOW() - INTERVAL '90 days'
),
user_tenants AS (
  SELECT 
    iu.user_id,
    t.id as tenant_id
  FROM incomplete_users iu
  JOIN sms_gateway.tenants t ON t.slug = iu.client_slug || '-' || substring(iu.user_id::text, 1, 8)
)
INSERT INTO sms_gateway.tenant_members (user_id, tenant_id, role)
SELECT user_id, tenant_id, 'owner'
FROM user_tenants
ON CONFLICT (user_id, tenant_id) DO NOTHING
RETURNING user_id, tenant_id;

-- Step 5: Create user settings
WITH incomplete_settings AS (
  SELECT au.id as user_id
  FROM auth.users au
  JOIN sms_gateway.users u ON u.id = au.id
  LEFT JOIN sms_gateway.user_settings us ON us.user_id = au.id
  WHERE us.user_id IS NULL 
    AND au.created_at > NOW() - INTERVAL '90 days'
)
INSERT INTO sms_gateway.user_settings (user_id, theme_mode, notification_enabled, auto_sync_enabled)
SELECT user_id, 'system', true, true
FROM incomplete_settings
ON CONFLICT (user_id) DO NOTHING
RETURNING user_id;

-- Step 6: Create tenant settings
WITH incomplete_tenants AS (
  SELECT DISTINCT t.id as tenant_id
  FROM auth.users au
  JOIN sms_gateway.users u ON u.id = au.id
  JOIN sms_gateway.tenants t ON t.id = u.tenant_id
  LEFT JOIN sms_gateway.tenant_settings ts ON ts.tenant_id = t.id
  WHERE ts.tenant_id IS NULL 
    AND au.created_at > NOW() - INTERVAL '90 days'
)
INSERT INTO sms_gateway.tenant_settings (tenant_id, max_users, max_contacts, max_sms_per_month, features)
SELECT tenant_id, 10, 10000, 10000, '{"bulk_sms": true}'::jsonb
FROM incomplete_tenants
ON CONFLICT (tenant_id) DO NOTHING
RETURNING tenant_id;

-- Step 7: Create global users
WITH incomplete_users AS (
  SELECT 
    au.id as user_id,
    au.email,
    c.id as client_id
  FROM auth.users au
  JOIN public.clients c ON c.owner_id = au.id
  JOIN sms_gateway.users u ON u.id = au.id
  LEFT JOIN public.global_users gu ON gu.id = au.id
  WHERE gu.id IS NULL 
    AND au.created_at > NOW() - INTERVAL '90 days'
)
INSERT INTO public.global_users (id, email, name, client_id, role, is_client_owner)
SELECT 
  user_id,
  email,
  SPLIT_PART(email, '@', 1),
  client_id,
  'admin',
  true
FROM incomplete_users
ON CONFLICT (id) DO NOTHING
RETURNING id, email;

-- Step 8: Create product access
WITH incomplete_users AS (
  SELECT 
    au.id as user_id,
    c.id as client_id,
    u.tenant_id,
    p.id as product_id
  FROM auth.users au
  JOIN public.clients c ON c.owner_id = au.id
  JOIN sms_gateway.users u ON u.id = au.id
  CROSS JOIN public.products p
  LEFT JOIN public.client_product_access cpa ON cpa.user_id = au.id AND cpa.product_id = p.id
  WHERE cpa.user_id IS NULL 
    AND p.schema_name = 'sms_gateway'
    AND au.created_at > NOW() - INTERVAL '90 days'
)
INSERT INTO public.client_product_access (user_id, client_id, product_id, tenant_id, role)
SELECT user_id, client_id, product_id, tenant_id, 'owner'
FROM incomplete_users
ON CONFLICT (user_id, client_id, product_id) DO NOTHING
RETURNING user_id, product_id;

-- Step 9: Create product subscriptions
WITH incomplete_subs AS (
  SELECT 
    p.id as product_id,
    c.id as client_id,
    u.tenant_id
  FROM auth.users au
  JOIN public.clients c ON c.owner_id = au.id
  JOIN sms_gateway.users u ON u.id = au.id
  CROSS JOIN public.products p
  LEFT JOIN public.product_subscriptions ps ON ps.client_id = c.id AND ps.product_id = p.id AND ps.tenant_id = u.tenant_id
  WHERE ps.product_id IS NULL 
    AND p.schema_name = 'sms_gateway'
    AND au.created_at > NOW() - INTERVAL '90 days'
)
INSERT INTO public.product_subscriptions (product_id, client_id, tenant_id, status, subscription_type, start_date)
SELECT product_id, client_id, tenant_id, 'active', 'standard', NOW()
FROM incomplete_subs
ON CONFLICT DO NOTHING
RETURNING product_id, client_id, tenant_id;

-- Final verification
SELECT 
  'FINAL VERIFICATION' as step,
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE u.id IS NOT NULL) as complete_users,
  COUNT(*) FILTER (WHERE u.id IS NULL) as incomplete_users
FROM auth.users au
LEFT JOIN sms_gateway.users u ON u.id = au.id
WHERE au.created_at > NOW() - INTERVAL '90 days';
