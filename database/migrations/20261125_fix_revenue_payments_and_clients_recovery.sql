-- ==============================================================================
-- Migration: Fix Revenue, Payments RLS, Tenant Settings Constraint & Recover Clients
-- Date: 2026-11-25
-- Description:
--   1. Fixes check constraint "tenant_settings_default_sms_channel_check" to allow
--      'thisPhone', 'quickSMS', 'swalaSMS', and 'cloudSMS' (prevents error 23514).
--   2. Grants Admin & Authenticated UPDATE / SELECT access to sms_gateway.payments
--      so admin dashboard sees real revenue and client app can verify payments.
--   3. Auto-recovers all registered auth users (including muhangisystem@gmail.com)
--      into sms_gateway.tenants, tenant_members, tenant_settings, and public.clients.
--   4. Displays current payment records and their statuses.
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. FIX CHECK CONSTRAINT ON sms_gateway.tenant_settings & ENSURE COLUMNS
-- ------------------------------------------------------------------------------
ALTER TABLE sms_gateway.tenant_settings 
DROP CONSTRAINT IF EXISTS tenant_settings_default_sms_channel_check;

ALTER TABLE sms_gateway.tenant_settings 
ADD CONSTRAINT tenant_settings_default_sms_channel_check 
CHECK (default_sms_channel IN ('thisPhone', 'quickSMS', 'swalaSMS', 'cloudSMS'));

-- Ensure phone_number exists on sms_gateway.users
ALTER TABLE sms_gateway.users ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- Ensure sms_gateway_tenant_id exists on public.clients
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'clients') THEN
    ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS sms_gateway_tenant_id UUID;
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. FIX RLS ON sms_gateway.payments
-- ------------------------------------------------------------------------------
ALTER TABLE sms_gateway.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view tenant payments" ON sms_gateway.payments;
DROP POLICY IF EXISTS "Admin and users can view payments" ON sms_gateway.payments;

CREATE POLICY "Admin and users can view payments"
ON sms_gateway.payments
FOR SELECT
TO authenticated
USING (
    -- Client viewing own tenant payments
    tenant_id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
    OR user_id = auth.uid()
    -- Admin users viewing all payments across all tenants
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

DROP POLICY IF EXISTS "Users can insert payments" ON sms_gateway.payments;
CREATE POLICY "Users can insert payments"
ON sms_gateway.payments
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

DROP POLICY IF EXISTS "Users can update tenant payments" ON sms_gateway.payments;
DROP POLICY IF EXISTS "Admin and users can update payments" ON sms_gateway.payments;

CREATE POLICY "Admin and users can update payments"
ON sms_gateway.payments
FOR UPDATE
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

-- Service role bypass
DROP POLICY IF EXISTS "Service role full access on payments" ON sms_gateway.payments;
CREATE POLICY "Service role full access on payments"
ON sms_gateway.payments
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ------------------------------------------------------------------------------
-- 3. FIX RLS ON sms_gateway.tenants & tenant_settings FOR ADMIN VISIBILITY
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admin and members can view tenants" ON sms_gateway.tenants;
CREATE POLICY "Admin and members can view tenants"
ON sms_gateway.tenants
FOR SELECT
TO authenticated
USING (
    id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
    OR auth.jwt() ->> 'email' IN ('lwena@techware.africa', 'admin@techware.africa', 'adamlwena@gmail.com')
    OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM public.global_users gu 
        WHERE gu.id = auth.uid() AND gu.role IN ('super_admin', 'admin')
    )
    OR EXISTS (
        SELECT 1 FROM sms_gateway.users u 
        WHERE u.id = auth.uid() AND u.role = 'superadmin'
    )
);

DROP POLICY IF EXISTS "Admin and members can view tenant settings" ON sms_gateway.tenant_settings;
CREATE POLICY "Admin and members can view tenant settings"
ON sms_gateway.tenant_settings
FOR SELECT
TO authenticated
USING (
    tenant_id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
    OR auth.jwt() ->> 'email' IN ('lwena@techware.africa', 'admin@techware.africa', 'adamlwena@gmail.com')
    OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM public.global_users gu 
        WHERE gu.id = auth.uid() AND gu.role IN ('super_admin', 'admin')
    )
);

DROP POLICY IF EXISTS "Admin and members can update tenant settings" ON sms_gateway.tenant_settings;
CREATE POLICY "Admin and members can update tenant settings"
ON sms_gateway.tenant_settings
FOR UPDATE
TO authenticated
USING (
    tenant_id IN (
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
    OR auth.jwt() ->> 'email' IN ('lwena@techware.africa', 'admin@techware.africa', 'adamlwena@gmail.com')
    OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM public.global_users gu 
        WHERE gu.id = auth.uid() AND gu.role IN ('super_admin', 'admin')
    )
);

-- ------------------------------------------------------------------------------
-- 4. AUTO-RECOVER & SYNC ALL REGISTERED CLIENTS (e.g. muhangisystem@gmail.com)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_user RECORD;
  v_tenant_id UUID;
  v_client_id UUID;
  v_company_name TEXT;
  v_user_name TEXT;
  v_user_phone TEXT;
BEGIN
  FOR v_user IN 
    SELECT 
      u.id, 
      u.email, 
      u.raw_user_meta_data,
      u.created_at
    FROM auth.users u
  LOOP
    -- Extract metadata
    v_company_name := COALESCE(
      v_user.raw_user_meta_data->>'company_name',
      v_user.raw_user_meta_data->>'organization_name',
      split_part(v_user.email, '@', 1) || ' Organization'
    );
    v_user_name := COALESCE(
      v_user.raw_user_meta_data->>'name',
      v_user.raw_user_meta_data->>'full_name',
      split_part(v_user.email, '@', 1)
    );
    v_user_phone := v_user.raw_user_meta_data->>'phone';

    -- A. Check or Create Tenant in sms_gateway.tenants
    SELECT tenant_id INTO v_tenant_id 
    FROM sms_gateway.tenant_members 
    WHERE user_id = v_user.id 
    LIMIT 1;

    IF v_tenant_id IS NULL THEN
      SELECT tenant_id INTO v_tenant_id 
      FROM sms_gateway.users 
      WHERE id = v_user.id 
      LIMIT 1;
    END IF;

    IF v_tenant_id IS NULL THEN
      INSERT INTO sms_gateway.tenants (name, slug, is_active, created_at, updated_at)
      VALUES (
        v_company_name,
        lower(regexp_replace(v_company_name, '[^a-zA-Z0-9]', '-', 'g')) || '-' || substr(v_user.id::text, 1, 6),
        true,
        v_user.created_at,
        now()
      )
      RETURNING id INTO v_tenant_id;
    END IF;

    -- B. Ensure membership in sms_gateway.tenant_members
    INSERT INTO sms_gateway.tenant_members (tenant_id, user_id, role, created_at)
    VALUES (v_tenant_id, v_user.id, 'owner', v_user.created_at)
    ON CONFLICT (tenant_id, user_id) DO NOTHING;

    -- C. Ensure user profile in sms_gateway.users
    INSERT INTO sms_gateway.users (id, tenant_id, email, name, role)
    VALUES (
      v_user.id,
      v_tenant_id,
      v_user.email,
      v_user_name,
      'owner'
    )
    ON CONFLICT (id) DO UPDATE SET
      tenant_id = EXCLUDED.tenant_id,
      email = EXCLUDED.email,
      name = COALESCE(sms_gateway.users.name, EXCLUDED.name);

    -- Update phone_number if available
    IF v_user_phone IS NOT NULL AND v_user_phone <> '' THEN
      BEGIN
        UPDATE sms_gateway.users 
        SET phone_number = v_user_phone 
        WHERE id = v_user.id;
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;

    -- D. Ensure tenant_settings exist with safe default channel 'thisPhone'
    INSERT INTO sms_gateway.tenant_settings (
      tenant_id, 
      default_sms_channel, 
      daily_sms_quota, 
      monthly_sms_quota, 
      plan_type, 
      enable_bulk_sms
    )
    VALUES (
      v_tenant_id, 
      'thisPhone', 
      100, 
      1000, 
      'basic', 
      true
    )
    ON CONFLICT (tenant_id) DO NOTHING;

    -- E. Link to Central public.clients (for TechWareAfrica Admin Panel)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'clients') THEN
      SELECT id INTO v_client_id 
      FROM public.clients 
      WHERE contact_email = v_user.email 
      LIMIT 1;

      IF v_client_id IS NULL THEN
        INSERT INTO public.clients (
          name, 
          company_name, 
          contact_email, 
          contact_phone, 
          is_active, 
          sms_gateway_tenant_id, 
          created_at, 
          updated_at
        )
        VALUES (
          v_user_name,
          v_company_name,
          v_user.email,
          v_user_phone,
          true,
          v_tenant_id,
          v_user.created_at,
          now()
        )
        ON CONFLICT DO NOTHING;
      ELSE
        UPDATE public.clients 
        SET sms_gateway_tenant_id = v_tenant_id,
            updated_at = now()
        WHERE id = v_client_id AND (sms_gateway_tenant_id IS NULL OR sms_gateway_tenant_id <> v_tenant_id);
      END IF;
    END IF;

  END LOOP;
  RAISE NOTICE '✅ Successfully synced all users and tenants!';
END $$;

COMMIT;

-- ------------------------------------------------------------------------------
-- 5. DIAGNOSTIC QUERY: VIEW ALL PAYMENTS AND CLIENT STATUS
-- ------------------------------------------------------------------------------
SELECT 
  p.id,
  p.transaction_id,
  p.amount,
  p.currency,
  p.phone_number,
  p.plan_name,
  p.status,
  p.provider,
  p.metadata->>'credited' AS is_credited,
  t.name AS tenant_name,
  p.created_at
FROM sms_gateway.payments p
LEFT JOIN sms_gateway.tenants t ON t.id = p.tenant_id
ORDER BY p.created_at DESC;
