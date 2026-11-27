-- ==============================================================================
-- Migration: Reconcile Muhangi's SMS Quota & Prevent Free Credit Inflation
-- Date: 2026-11-27
-- ==============================================================================

BEGIN;

-- 1. Fix Muhangi's Workspace SMS Quota
-- The previous migration added 1,000 SMS credits on top of an old default 1,000,
-- resulting in 2,000 credits for 1 payment of 15,000 TZS (1,000 SMS).
-- Reconcile to exactly 1,000 SMS credits:
UPDATE sms_gateway.tenant_settings
SET 
  monthly_sms_quota = 1000,
  updated_at = now()
WHERE tenant_id IN (
  SELECT t.id 
  FROM sms_gateway.tenants t
  JOIN sms_gateway.payments p ON p.tenant_id = t.id
  WHERE p.transaction_id = 'SGW_1795529393530_3bed1425'
     OR t.name ILIKE '%muhangi%'
)
AND monthly_sms_quota = 2000;

-- 2. Ensure all newly created tenant_settings default to 0 credits (pay-as-you-go)
ALTER TABLE sms_gateway.tenant_settings 
ALTER COLUMN monthly_sms_quota SET DEFAULT 0;

COMMIT;
