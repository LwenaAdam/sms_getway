-- Fix RLS policies for registration flow
-- Problem: Circular dependency between tenants and users tables during registration
-- Solution: Allow tenant creation without checking users table (which doesn't exist yet)

BEGIN;

-- =============================================================================
-- FIX: sms_gateway.tenants - Remove circular dependency
-- =============================================================================

-- Drop existing policies that cause circular dependency
DROP POLICY IF EXISTS "tenants_insert_any" ON sms_gateway.tenants;
DROP POLICY IF EXISTS "tenants_select_own" ON sms_gateway.tenants;
DROP POLICY IF EXISTS "tenants_update_admin" ON sms_gateway.tenants;

-- Create fixed policies without circular dependency

-- 1. Allow ANY authenticated user to insert a tenant (needed for registration)
-- This doesn't check users table because user profile doesn't exist yet
CREATE POLICY "tenants_insert_authenticated"
ON sms_gateway.tenants
FOR INSERT
TO authenticated
WITH CHECK (true);

-- 2. Allow users to SELECT their tenant
-- During registration: User just created the tenant, so they can select it
-- After registration: User can see their tenant from users table
CREATE POLICY "tenants_select_own_or_all"
ON sms_gateway.tenants
FOR SELECT
TO authenticated
USING (
  -- Option 1: User is a member of this tenant (after registration)
  id IN (
    SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
  )
  OR
  -- Option 2: User just created this tenant via client_id (during registration)
  client_id IN (
    SELECT id FROM public.clients WHERE owner_id = auth.uid()
  )
);

-- 3. Allow tenant admins/owners to update
CREATE POLICY "tenants_update_by_role"
ON sms_gateway.tenants
FOR UPDATE
TO authenticated
USING (
  -- Check via users table
  id IN (
    SELECT tenant_id FROM sms_gateway.users 
    WHERE id = auth.uid() AND role IN ('owner', 'admin')
  )
  OR
  -- Check via client ownership
  client_id IN (
    SELECT id FROM public.clients WHERE owner_id = auth.uid()
  )
)
WITH CHECK (
  -- Check via users table
  id IN (
    SELECT tenant_id FROM sms_gateway.users 
    WHERE id = auth.uid() AND role IN ('owner', 'admin')
  )
  OR
  -- Check via client ownership
  client_id IN (
    SELECT id FROM public.clients WHERE owner_id = auth.uid()
  )
);

COMMIT;

-- =============================================================================
-- VERIFICATION: Check tenant policies
-- =============================================================================

SELECT 
  schemaname,
  tablename,
  policyname,
  cmd as command,
  CASE 
    WHEN qual IS NOT NULL THEN 'Has USING'
    ELSE 'No USING'
  END as using_clause,
  CASE 
    WHEN with_check IS NOT NULL THEN 'Has WITH CHECK'
    ELSE 'No WITH CHECK'
  END as with_check_clause
FROM pg_policies
WHERE schemaname = 'sms_gateway' AND tablename = 'tenants'
ORDER BY policyname;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Tenant RLS policies fixed - circular dependency removed';
  RAISE NOTICE '✅ Users can now create tenants during registration';
  RAISE NOTICE '✅ Policies work both during and after registration';
END $$;
