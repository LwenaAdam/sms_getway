-- Fix RLS policies for all registration-related tables
-- Run this in your Supabase SQL Editor

-- =============================================================================
-- 1. FIX: sms_gateway.tenants - Allow tenant creation during registration
-- =============================================================================

-- Drop existing conflicting policies
DROP POLICY IF EXISTS "Users can insert their own tenant during registration" ON sms_gateway.tenants;
DROP POLICY IF EXISTS "Allow tenant creation during registration" ON sms_gateway.tenants;
DROP POLICY IF EXISTS "Users can view their tenant" ON sms_gateway.tenants;
DROP POLICY IF EXISTS "Tenant owners can update tenant" ON sms_gateway.tenants;

-- Enable RLS
ALTER TABLE sms_gateway.tenants ENABLE ROW LEVEL SECURITY;

-- Allow any authenticated user to create a tenant (needed for registration)
CREATE POLICY "Allow tenant creation during registration"
ON sms_gateway.tenants
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow users to view their own tenant
CREATE POLICY "Users can view their tenant"
ON sms_gateway.tenants
FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT tenant_id 
    FROM sms_gateway.users 
    WHERE id = auth.uid()
  )
);

-- Allow tenant owners/admins to update
CREATE POLICY "Tenant owners can update"
ON sms_gateway.tenants
FOR UPDATE
TO authenticated
USING (
  id IN (
    SELECT tenant_id 
    FROM sms_gateway.users 
    WHERE id = auth.uid() 
    AND role IN ('owner', 'admin')
  )
);

-- =============================================================================
-- 2. FIX: sms_gateway.users - Allow user profile creation during registration
-- =============================================================================

DROP POLICY IF EXISTS "Users can insert their own profile" ON sms_gateway.users;
DROP POLICY IF EXISTS "Users can view their own profile" ON sms_gateway.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON sms_gateway.users;

ALTER TABLE sms_gateway.users ENABLE ROW LEVEL SECURITY;

-- Allow users to create their own profile
CREATE POLICY "Users can insert their own profile"
ON sms_gateway.users
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Allow users to view their own profile
CREATE POLICY "Users can view their own profile"
ON sms_gateway.users
FOR SELECT
TO authenticated
USING (id = auth.uid());

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile"
ON sms_gateway.users
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- =============================================================================
-- 3. FIX: sms_gateway.tenant_members - Allow membership creation
-- =============================================================================

DROP POLICY IF EXISTS "Users can create tenant membership" ON sms_gateway.tenant_members;
DROP POLICY IF EXISTS "Users can view tenant members" ON sms_gateway.tenant_members;

ALTER TABLE sms_gateway.tenant_members ENABLE ROW LEVEL SECURITY;

-- Allow users to create their own membership
CREATE POLICY "Users can create tenant membership"
ON sms_gateway.tenant_members
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Allow users to view members of their tenant
CREATE POLICY "Users can view tenant members"
ON sms_gateway.tenant_members
FOR SELECT
TO authenticated
USING (
  tenant_id IN (
    SELECT tenant_id 
    FROM sms_gateway.users 
    WHERE id = auth.uid()
  )
);

-- =============================================================================
-- 4. FIX: sms_gateway.user_settings - Allow settings creation
-- =============================================================================

DROP POLICY IF EXISTS "Users can create their settings" ON sms_gateway.user_settings;
DROP POLICY IF EXISTS "Users can view their settings" ON sms_gateway.user_settings;
DROP POLICY IF EXISTS "Users can update their settings" ON sms_gateway.user_settings;

ALTER TABLE sms_gateway.user_settings ENABLE ROW LEVEL SECURITY;

-- Allow users to create their settings
CREATE POLICY "Users can create their settings"
ON sms_gateway.user_settings
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Allow users to view their settings
CREATE POLICY "Users can view their settings"
ON sms_gateway.user_settings
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Allow users to update their settings
CREATE POLICY "Users can update their settings"
ON sms_gateway.user_settings
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- =============================================================================
-- 5. FIX: sms_gateway.tenant_settings - Allow tenant settings creation
-- =============================================================================

DROP POLICY IF EXISTS "Allow tenant settings creation" ON sms_gateway.tenant_settings;
DROP POLICY IF EXISTS "Users can view tenant settings" ON sms_gateway.tenant_settings;
DROP POLICY IF EXISTS "Admins can update tenant settings" ON sms_gateway.tenant_settings;

ALTER TABLE sms_gateway.tenant_settings ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to create tenant settings
CREATE POLICY "Allow tenant settings creation"
ON sms_gateway.tenant_settings
FOR INSERT
TO authenticated
WITH CHECK (
  tenant_id IN (
    SELECT tenant_id 
    FROM sms_gateway.users 
    WHERE id = auth.uid()
  )
);

-- Allow users to view their tenant settings
CREATE POLICY "Users can view tenant settings"
ON sms_gateway.tenant_settings
FOR SELECT
TO authenticated
USING (
  tenant_id IN (
    SELECT tenant_id 
    FROM sms_gateway.users 
    WHERE id = auth.uid()
  )
);

-- Allow admins to update tenant settings
CREATE POLICY "Admins can update tenant settings"
ON sms_gateway.tenant_settings
FOR UPDATE
TO authenticated
USING (
  tenant_id IN (
    SELECT tenant_id 
    FROM sms_gateway.users 
    WHERE id = auth.uid() 
    AND role IN ('owner', 'admin')
  )
);

-- =============================================================================
-- 6. FIX: public.clients - Allow client creation during registration
-- =============================================================================

DROP POLICY IF EXISTS "Allow client creation" ON public.clients;
DROP POLICY IF EXISTS "Users can view their client" ON public.clients;
DROP POLICY IF EXISTS "Client owners can update" ON public.clients;

ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to create clients
CREATE POLICY "Allow client creation"
ON public.clients
FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

-- Allow users to view their client
CREATE POLICY "Users can view their client"
ON public.clients
FOR SELECT
TO authenticated
USING (owner_id = auth.uid());

-- Allow client owners to update
CREATE POLICY "Client owners can update"
ON public.clients
FOR UPDATE
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- =============================================================================
-- 7. FIX: public.client_product_access - Allow product access creation
-- =============================================================================

DROP POLICY IF EXISTS "Allow product access creation" ON public.client_product_access;
DROP POLICY IF EXISTS "Users can view their product access" ON public.client_product_access;

ALTER TABLE public.client_product_access ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to create product access
CREATE POLICY "Allow product access creation"
ON public.client_product_access
FOR INSERT
TO authenticated
WITH CHECK (
  client_id IN (
    SELECT id FROM public.clients WHERE owner_id = auth.uid()
  )
);

-- Allow users to view their product access
CREATE POLICY "Users can view their product access"
ON public.client_product_access
FOR SELECT
TO authenticated
USING (
  client_id IN (
    SELECT id FROM public.clients WHERE owner_id = auth.uid()
  )
);

-- =============================================================================
-- VERIFICATION: Check all policies
-- =============================================================================

SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd as command,
  CASE 
    WHEN qual IS NOT NULL THEN 'Has USING clause'
    ELSE 'No USING clause'
  END as using_clause,
  CASE 
    WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
    ELSE 'No WITH CHECK clause'
  END as with_check_clause
FROM pg_policies
WHERE 
  (schemaname = 'sms_gateway' AND tablename IN ('tenants', 'users', 'tenant_members', 'user_settings', 'tenant_settings'))
  OR (schemaname = 'public' AND tablename IN ('clients', 'client_product_access'))
ORDER BY schemaname, tablename, policyname;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ All RLS policies for registration have been updated successfully';
  RAISE NOTICE '✅ Users can now complete the registration process';
  RAISE NOTICE '✅ Tables updated: tenants, users, tenant_members, user_settings, tenant_settings, clients, client_product_access';
END $$;
