-- ============================================================
-- CONSOLIDATED MIGRATION FOR SMS GATEWAY (RUN IN SUPABASE SQL EDITOR)
-- Project: kzjgdeqfmxkmpmadtbpb
-- Date: 2026-11-22
-- ============================================================

-- Ensure schema exists
CREATE SCHEMA IF NOT EXISTS sms_gateway;

-- ------------------------------------------------------------
-- 1. FIX TENANT MEMBERS UPDATE RLS (Fixes 403 Forbidden on upsert)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Users can update their tenant membership" ON sms_gateway.tenant_members;

CREATE POLICY "Users can update their tenant membership"
ON sms_gateway.tenant_members
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());


-- ------------------------------------------------------------
-- 2. CREATE PAYMENTS TABLE (For Palm Pesa Tanzania mobile money)
-- ------------------------------------------------------------
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

-- Indexes for payments
CREATE INDEX IF NOT EXISTS idx_payments_tenant_id ON sms_gateway.payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_id ON sms_gateway.payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON sms_gateway.payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON sms_gateway.payments(status);

-- Enable RLS for payments
ALTER TABLE sms_gateway.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view tenant payments" ON sms_gateway.payments;
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

DROP POLICY IF EXISTS "Users can insert payments" ON sms_gateway.payments;
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

DROP POLICY IF EXISTS "Users can update tenant payments" ON sms_gateway.payments;
CREATE POLICY "Users can update tenant payments"
ON sms_gateway.payments
FOR UPDATE
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

DROP POLICY IF EXISTS "Service role full access on payments" ON sms_gateway.payments;
CREATE POLICY "Service role full access on payments"
ON sms_gateway.payments
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);


-- ------------------------------------------------------------
-- 3. CREATE PROVIDER TABLES (Eliminates relation does not exist 42P01)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sms_gateway.sms_providers (
    id TEXT PRIMARY KEY,
    tenant_id UUID REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    endpoint_url TEXT NOT NULL,
    http_method VARCHAR(10) NOT NULL DEFAULT 'POST',
    auth_type VARCHAR(30) NOT NULL DEFAULT 'bearer',
    auth_header_key VARCHAR(50) NOT NULL DEFAULT 'Authorization',
    api_key TEXT NOT NULL DEFAULT '',
    api_secret TEXT,
    sender_id VARCHAR(50) NOT NULL DEFAULT 'SMS_GATEWAY',
    body_template TEXT,
    custom_headers JSONB,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sms_providers_tenant_id ON sms_gateway.sms_providers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_providers_slug ON sms_gateway.sms_providers(slug);
CREATE INDEX IF NOT EXISTS idx_sms_providers_is_default ON sms_gateway.sms_providers(is_default);

ALTER TABLE sms_gateway.sms_providers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read sms_providers" ON sms_gateway.sms_providers;
CREATE POLICY "Allow authenticated users to read sms_providers"
ON sms_gateway.sms_providers
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Service role full access on sms_providers" ON sms_gateway.sms_providers;
CREATE POLICY "Service role full access on sms_providers"
ON sms_gateway.sms_providers
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

CREATE TABLE IF NOT EXISTS sms_gateway.payment_providers (
    id TEXT PRIMARY KEY,
    tenant_id UUID REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    base_url TEXT NOT NULL DEFAULT '',
    endpoint_url TEXT NOT NULL DEFAULT '',
    merchant_id TEXT,
    api_token TEXT NOT NULL DEFAULT '',
    api_secret TEXT,
    currency VARCHAR(10) NOT NULL DEFAULT 'TZS',
    payment_type VARCHAR(50) NOT NULL DEFAULT 'mobile_money_ussd',
    supported_channels JSONB DEFAULT '["Vodacom M-Pesa", "Tigo Pesa", "Airtel Money", "HaloPesa"]'::jsonb,
    callback_url TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_providers_tenant_id ON sms_gateway.payment_providers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payment_providers_slug ON sms_gateway.payment_providers(slug);
CREATE INDEX IF NOT EXISTS idx_payment_providers_is_default ON sms_gateway.payment_providers(is_default);

ALTER TABLE sms_gateway.payment_providers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read payment_providers" ON sms_gateway.payment_providers;
CREATE POLICY "Allow authenticated users to read payment_providers"
ON sms_gateway.payment_providers
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Service role full access on payment_providers" ON sms_gateway.payment_providers;
CREATE POLICY "Service role full access on payment_providers"
ON sms_gateway.payment_providers
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ------------------------------------------------------------
-- 4. CREATE SENDER ID REQUESTS TABLE
-- ------------------------------------------------------------
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

ALTER TABLE sms_gateway.sender_id_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their tenant sender_id_requests" ON sms_gateway.sender_id_requests;
CREATE POLICY "Users can view their tenant sender_id_requests"
ON sms_gateway.sender_id_requests
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

DROP POLICY IF EXISTS "Users can insert sender_id_requests" ON sms_gateway.sender_id_requests;
CREATE POLICY "Users can insert sender_id_requests"
ON sms_gateway.sender_id_requests
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

DROP POLICY IF EXISTS "Service role full access on sender_id_requests" ON sms_gateway.sender_id_requests;
CREATE POLICY "Service role full access on sender_id_requests"
ON sms_gateway.sender_id_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

