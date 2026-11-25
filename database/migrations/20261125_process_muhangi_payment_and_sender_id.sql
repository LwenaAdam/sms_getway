-- ==============================================================================
-- Migration: Process Muhangi's 15,000 TZS Payment and Approve Sender ID
-- Date: 2026-11-25
-- ==============================================================================

BEGIN;

-- 1. Ensure Admin can view and update sender_id_requests
ALTER TABLE sms_gateway.sender_id_requests ENABLE ROW LEVEL SECURITY;

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
);

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
);

-- Service role bypass
DROP POLICY IF EXISTS "Service role full access on sender_id_requests" ON sms_gateway.sender_id_requests;
CREATE POLICY "Service role full access on sender_id_requests"
ON sms_gateway.sender_id_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);


-- 2. Process Muhangi's 15,000 TZS Payment (Transaction ID: SGW_1795529393530_3bed1425)
DO $$
DECLARE
  v_payment_id UUID;
  v_tenant_id UUID;
  v_current_quota INT;
  v_new_quota INT;
BEGIN
  -- A. Find payment record
  SELECT id, tenant_id INTO v_payment_id, v_tenant_id
  FROM sms_gateway.payments
  WHERE transaction_id = 'SGW_1795529393530_3bed1425'
     OR (phone_number = '255616629143' AND amount = 15000.00)
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_payment_id IS NOT NULL THEN
    -- Mark payment completed and credited
    UPDATE sms_gateway.payments
    SET 
      status = 'completed',
      metadata = jsonb_build_object(
        'credited', true,
        'credited_at', now(),
        'credited_by', 'admin',
        'sms_credits_added', 1000,
        'verified_via', 'Admin Approval'
      ),
      updated_at = now()
    WHERE id = v_payment_id;

    RAISE NOTICE '✅ Payment % marked as COMPLETED!', v_payment_id;

    -- B. Credit Quota in tenant_settings (+1,000 SMS)
    IF v_tenant_id IS NOT NULL THEN
      SELECT COALESCE(monthly_sms_quota, 1000) INTO v_current_quota
      FROM sms_gateway.tenant_settings
      WHERE tenant_id = v_tenant_id;

      v_new_quota := COALESCE(v_current_quota, 1000) + 1000;

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
        500,
        v_new_quota,
        'basic',
        true
      )
      ON CONFLICT (tenant_id) DO UPDATE SET
        monthly_sms_quota = EXCLUDED.monthly_sms_quota,
        enable_bulk_sms = true,
        updated_at = now();

      RAISE NOTICE '✅ Muhangi Tenant % quota updated to % SMS!', v_tenant_id, v_new_quota;
    END IF;

  ELSE
    RAISE NOTICE '⚠️ Muhangi payment record not found by ID or phone';
  END IF;

  -- C. Approve Muhangi's Sender ID Request
  UPDATE sms_gateway.sender_id_requests
  SET 
    status = 'approved',
    updated_at = now()
  WHERE (
    tenant_id = v_tenant_id 
    OR contact_phone = '255616629143' 
    OR lower(business_name) LIKE '%muhangi%'
  )
  AND status = 'pending';

  RAISE NOTICE '✅ Muhangi Sender ID request approved!';

END $$;

COMMIT;

-- 3. VERIFY MUHANGI PAYMENT STATUS, QUOTA, AND SENDER ID
SELECT 
  'PAYMENT' AS item_type,
  p.transaction_id AS reference,
  p.amount::text || ' ' || p.currency AS details,
  p.status AS status,
  p.metadata->>'credited' AS extra_info,
  t.name AS tenant_name
FROM sms_gateway.payments p
LEFT JOIN sms_gateway.tenants t ON t.id = p.tenant_id
WHERE p.transaction_id = 'SGW_1795529393530_3bed1425'

UNION ALL

SELECT 
  'SMS QUOTA' AS item_type,
  ts.plan_type AS reference,
  'Monthly Quota: ' || ts.monthly_sms_quota::text || ' SMS' AS details,
  CASE WHEN ts.enable_bulk_sms THEN 'ENABLED' ELSE 'DISABLED' END AS status,
  'Daily: ' || ts.daily_sms_quota::text AS extra_info,
  t.name AS tenant_name
FROM sms_gateway.tenant_settings ts
JOIN sms_gateway.tenants t ON t.id = ts.tenant_id
WHERE t.name ILIKE '%muhangi%'

UNION ALL

SELECT 
  'SENDER ID' AS item_type,
  sr.sender_id AS reference,
  'Business: ' || sr.business_name AS details,
  sr.status AS status,
  'Phone: ' || sr.contact_phone AS extra_info,
  COALESCE(t.name, 'Muhangi') AS tenant_name
FROM sms_gateway.sender_id_requests sr
LEFT JOIN sms_gateway.tenants t ON t.id = sr.tenant_id
WHERE sr.contact_phone = '255616629143' OR lower(sr.business_name) LIKE '%muhangi%';
