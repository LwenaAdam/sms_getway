-- Fix RLS policy for tenants table to allow registration
-- This allows new users to create their own tenant during registration

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can insert their own tenant during registration" ON sms_gateway.tenants;
DROP POLICY IF EXISTS "Allow tenant creation during registration" ON sms_gateway.tenants;

-- Enable RLS on tenants table (if not already enabled)
ALTER TABLE sms_gateway.tenants ENABLE ROW LEVEL SECURITY;

-- Policy 1: Allow authenticated users to insert their own tenant
-- This is needed during registration when a user creates their organization
CREATE POLICY "Allow tenant creation during registration"
ON sms_gateway.tenants
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy 2: Allow users to view their own tenant
-- This uses the tenant_id from sms_gateway.users table
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

-- Policy 3: Allow tenant owners to update their tenant
CREATE POLICY "Tenant owners can update tenant"
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
)
WITH CHECK (
  id IN (
    SELECT tenant_id 
    FROM sms_gateway.users 
    WHERE id = auth.uid() 
    AND role IN ('owner', 'admin')
  )
);

-- Verify the policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'sms_gateway' AND tablename = 'tenants'
ORDER BY policyname;

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'RLS policies for sms_gateway.tenants have been updated successfully';
  RAISE NOTICE 'Users can now create tenants during registration';
END $$;
