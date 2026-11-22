-- ============================================================
-- Migration: Create SMS & Payment Providers tables in sms_gateway
-- Enables dynamic admin-managed provider integrations at runtime
-- ============================================================

-- 1. SMS Providers Table
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

-- Index for fast queries
CREATE INDEX IF NOT EXISTS idx_sms_providers_tenant_id ON sms_gateway.sms_providers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_providers_slug ON sms_gateway.sms_providers(slug);
CREATE INDEX IF NOT EXISTS idx_sms_providers_is_default ON sms_gateway.sms_providers(is_default);

-- Enable RLS
ALTER TABLE sms_gateway.sms_providers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to read sms_providers"
ON sms_gateway.sms_providers
FOR SELECT
TO authenticated
USING (
    tenant_id IS NULL OR tenant_id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
);

CREATE POLICY "Allow authenticated users to manage sms_providers"
ON sms_gateway.sms_providers
FOR ALL
TO authenticated
USING (
    tenant_id IS NULL OR tenant_id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
)
WITH CHECK (
    tenant_id IS NULL OR tenant_id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
);

CREATE POLICY "Service role full access on sms_providers"
ON sms_gateway.sms_providers
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);


-- 2. Payment Providers Table
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

-- Index for fast queries
CREATE INDEX IF NOT EXISTS idx_payment_providers_tenant_id ON sms_gateway.payment_providers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payment_providers_slug ON sms_gateway.payment_providers(slug);
CREATE INDEX IF NOT EXISTS idx_payment_providers_is_default ON sms_gateway.payment_providers(is_default);

-- Enable RLS
ALTER TABLE sms_gateway.payment_providers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to read payment_providers"
ON sms_gateway.payment_providers
FOR SELECT
TO authenticated
USING (
    tenant_id IS NULL OR tenant_id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
);

CREATE POLICY "Allow authenticated users to manage payment_providers"
ON sms_gateway.payment_providers
FOR ALL
TO authenticated
USING (
    tenant_id IS NULL OR tenant_id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
)
WITH CHECK (
    tenant_id IS NULL OR tenant_id IN (
        SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
        UNION
        SELECT tenant_id FROM sms_gateway.users WHERE id = auth.uid()
    )
);

CREATE POLICY "Service role full access on payment_providers"
ON sms_gateway.payment_providers
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
