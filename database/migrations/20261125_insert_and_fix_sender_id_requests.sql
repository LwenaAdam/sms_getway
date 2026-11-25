-- ==============================================================================
-- Migration: Ensure sender_id_requests table, fix RLS & Insert Muhangi Pending Request
-- Date: 2026-11-25
-- ==============================================================================

BEGIN;

-- 1. CREATE TABLE IF NOT EXISTS
CREATE TABLE IF NOT EXISTS sms_gateway.sender_id_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    sender_id VARCHAR(11) NOT NULL,
    business_name TEXT NOT NULL,
    purpose TEXT NOT NULL,
    contact_phone VARCHAR(30) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sender_id_requests_tenant ON sms_gateway.sender_id_requests(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sender_id_requests_status ON sms_gateway.sender_id_requests(status);

-- 2. ENABLE RLS AND CONFIGURE POLICIES
ALTER TABLE sms_gateway.sender_id_requests ENABLE ROW LEVEL SECURITY;

-- Allow SELECT for Users (own tenant) and Admins (all)
DROP POLICY IF EXISTS "Users can view their tenant sender_id_requests" ON sms_gateway.sender_id_requests;
DROP POLICY IF EXISTS "Admin and users can view sender_id_requests" ON sms_gateway.sender_id_requests;

CREATE POLICY "Admin and users can view sender_id_requests"
ON sms_gateway.sender_id_requests
FOR SELECT
TO authenticated
USING (
    tenant_id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
    OR user_id = auth.uid()
    OR auth.jwt() ->> 'email' IN ('lwena@techware.africa', 'admin@techware.africa', 'adamlwena@gmail.com')
    OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM public.global_users gu 
        WHERE gu.id = auth.uid() AND gu.role IN ('super_admin', 'admin')
    )
    OR EXISTS (
        SELECT 1 FROM sms_gateway.users u 
        WHERE u.id = auth.uid() AND u.role = 'superadmin'
    )
);

-- Allow INSERT for authenticated users
DROP POLICY IF EXISTS "Users can insert sender_id_requests" ON sms_gateway.sender_id_requests;
CREATE POLICY "Users can insert sender_id_requests"
ON sms_gateway.sender_id_requests
FOR INSERT
TO authenticated
WITH CHECK (
    tenant_id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
    OR user_id = auth.uid()
    OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- Allow UPDATE for Admin (to approve/reject)
DROP POLICY IF EXISTS "Admin and users can update sender_id_requests" ON sms_gateway.sender_id_requests;
CREATE POLICY "Admin and users can update sender_id_requests"
ON sms_gateway.sender_id_requests
FOR UPDATE
TO authenticated
USING (
    auth.jwt() ->> 'email' IN ('lwena@techware.africa', 'admin@techware.africa', 'adamlwena@gmail.com')
    OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM public.global_users gu 
        WHERE gu.id = auth.uid() AND gu.role IN ('super_admin', 'admin')
    )
    OR EXISTS (
        SELECT 1 FROM sms_gateway.users u 
        WHERE u.id = auth.uid() AND u.role = 'superadmin'
    )
);

-- Service role bypass
DROP POLICY IF EXISTS "Service role full access on sender_id_requests" ON sms_gateway.sender_id_requests;
CREATE POLICY "Service role full access on sender_id_requests"
ON sms_gateway.sender_id_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);


-- 3. INSERT PENDING SENDER ID REQUEST FOR MUHANGI
DO $$
DECLARE
  v_tenant_id UUID;
  v_user_id UUID;
  v_existing_id UUID;
BEGIN
  -- Tafuta tenant ya Muhangi
  SELECT id INTO v_tenant_id
  FROM sms_gateway.tenants
  WHERE name ILIKE '%muhangi%'
  LIMIT 1;

  -- Tafuta user_id ya Muhangi
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email ILIKE '%muhangi%'
  LIMIT 1;

  IF v_tenant_id IS NOT NULL THEN
    -- Angalia kama tayari kuna ombi
    SELECT id INTO v_existing_id
    FROM sms_gateway.sender_id_requests
    WHERE tenant_id = v_tenant_id
    LIMIT 1;

    IF v_existing_id IS NULL THEN
      INSERT INTO sms_gateway.sender_id_requests (
        tenant_id,
        user_id,
        sender_id,
        business_name,
        purpose,
        contact_phone,
        status,
        created_at,
        updated_at
      )
      VALUES (
        v_tenant_id,
        v_user_id,
        'MUHANGI',
        'Muhangi System',
        'Customer Notifications & Transactional SMS',
        '255616629143',
        'pending',
        now(),
        now()
      );
      RAISE NOTICE '✅ Ombi la Sender ID "MUHANGI" limewekwa kama PENDING!';
    ELSE
      -- Ikiwepo tayari, hakikisha status yake ni pending
      UPDATE sms_gateway.sender_id_requests
      SET status = 'pending', updated_at = now()
      WHERE id = v_existing_id AND status <> 'approved';
      RAISE NOTICE 'ℹ️ Ombi la Sender ID lilikuwepo tayari, limewekwa PENDING';
    END IF;
  ELSE
    RAISE NOTICE '⚠️ Tenant ya Muhangi haikupatikana';
  END IF;
END $$;

COMMIT;

-- 4. ONA MAOMBI YOTE YA SENDER ID KATIKA DATABASE
SELECT 
  sr.id,
  sr.sender_id,
  sr.business_name,
  sr.purpose,
  sr.contact_phone,
  sr.status,
  t.name AS tenant_name,
  sr.created_at
FROM sms_gateway.sender_id_requests sr
LEFT JOIN sms_gateway.tenants t ON t.id = sr.tenant_id
ORDER BY sr.created_at DESC;
