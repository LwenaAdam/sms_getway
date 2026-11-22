-- Migration: Allow authenticated users to update their own tenant membership
-- Needed for PostgREST .upsert() calls on sms_gateway.tenant_members
DROP POLICY IF EXISTS "Users can update their tenant membership" ON sms_gateway.tenant_members;

CREATE POLICY "Users can update their tenant membership"
ON sms_gateway.tenant_members
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
