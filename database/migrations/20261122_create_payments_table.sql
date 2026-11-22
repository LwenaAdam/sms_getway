-- ============================================================
-- Migration: Create payments table in sms_gateway schema
-- For tracking Palm Pesa Tanzania mobile money transactions
-- ============================================================

CREATE TABLE IF NOT EXISTS sms_gateway.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id TEXT NOT NULL UNIQUE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    tenant_id UUID REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
    amount NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'TZS',
    phone_number VARCHAR(30) NOT NULL,
    plan_name VARCHAR(100) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    provider VARCHAR(50) NOT NULL DEFAULT 'palmpesa',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast queries
CREATE INDEX IF NOT EXISTS idx_payments_tenant_id ON sms_gateway.payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_id ON sms_gateway.payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON sms_gateway.payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON sms_gateway.payments(status);

-- Enable RLS
ALTER TABLE sms_gateway.payments ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their tenant's payments
CREATE POLICY "Users can view tenant payments"
ON sms_gateway.payments
FOR SELECT
TO authenticated
USING (
    tenant_id IN (
        SELECT tenant_id 
        FROM sms_gateway.tenant_members 
        WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id
        FROM sms_gateway.users
        WHERE id = auth.uid()
    )
    OR user_id = auth.uid()
);

-- Policy: Users can insert payments for their tenant
CREATE POLICY "Users can insert payments"
ON sms_gateway.payments
FOR INSERT
TO authenticated
WITH CHECK (
    tenant_id IN (
        SELECT tenant_id 
        FROM sms_gateway.tenant_members 
        WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id
        FROM sms_gateway.users
        WHERE id = auth.uid()
    )
    OR user_id = auth.uid()
);

-- Policy: Service role has full access
CREATE POLICY "Service role full access on payments"
ON sms_gateway.payments
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
