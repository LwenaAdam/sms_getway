# 🗄️ Supabase Database Documentation

This document describes the database architecture for SMS Gateway Pro.

---

## � Quick Start: Local Development

### Running Against Local Supabase

Your local Supabase instance is running at:
- **Project URL**: `http://127.0.0.1:54321`
- **Studio**: `http://127.0.0.1:54323`
- **Database**: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
- **Anon Key**: `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH`

### Run Flutter App with Local Supabase

**Web (Chrome)**:
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
```

**Android** (use host IP, not 127.0.0.1):
```bash
# Find your host IP: ip addr show | grep inet
flutter run -d <device-id> \
  --dart-define=SUPABASE_URL=http://192.168.1.10:54321 \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
```

**Build for Production** (uses production Supabase):
```bash
flutter build web --release
# Uses default values from lib/core/constants.dart
```

### Local Supabase Management

**Start Supabase**:
```bash
cd ~/techwareafricaadimn
supabase start
```

**Stop Supabase**:
```bash
supabase stop
```

**Check Status**:
```bash
supabase status
```

**Access Studio** (GUI for database):
Open `http://127.0.0.1:54323` in browser

---

## �📊 Overview

SMS Gateway uses a **multi-tenant, multi-product SaaS architecture** with PostgreSQL schemas for complete data isolation.

```
┌─────────────────────────────────────────────────────────────┐
│                   SUPABASE DATABASE                          │
├─────────────────────────────────────────────────────────────┤
│  auth.*           │ Supabase built-in authentication        │
├───────────────────┼─────────────────────────────────────────┤
│  public.*         │ Control plane (clients, access control) │
├───────────────────┼─────────────────────────────────────────┤
│  sms_gateway.*    │ SMS Gateway application data            │
└───────────────────┴─────────────────────────────────────────┘
```

---

## 🔑 Connection Details

| Property | Value |
|----------|-------|
| **Project URL** | `https://kzjgdeqfmxkmpmadtbpb.supabase.co` |
| **Project Ref** | `kzjgdeqfmxkmpmadtbpb` |
| **Database Version** | PostgreSQL 15 |
| **Region** | Configured in Supabase Dashboard |

---

## 📁 Schema Structure

### `auth` Schema (Supabase Built-in)
Managed by Supabase - handles user authentication.

| Table | Description |
|-------|-------------|
| `auth.users` | User accounts (email, password hash) |
| `auth.sessions` | Active login sessions |

### `public` Schema (Control Plane)
Manages multi-tenant access control.

| Table | Description |
|-------|-------------|
| `products` | SaaS product catalog |
| `clients` | Organizations/companies |
| `global_users` | All users across products |
| `product_subscriptions` | Client-product relationships |
| `client_product_access` | User permissions per product |
| `product_usage_stats` | Usage metrics |

### `sms_gateway` Schema (Application Data)
SMS Gateway specific tables - **all have `tenant_id` for isolation**.

| Table | Description |
|-------|-------------|
| `users` | User profiles in SMS Gateway |
| `tenants` | Tenant workspaces |
| `tenant_members` | Tenant membership and roles |
| `contacts` | Phone contacts |
| `groups` | Contact groups |
| `group_members` | Group membership (many-to-many) |
| `sms_logs` | SMS sending history |
| `sms_requests` | API-triggered SMS queue |
| `api_keys` | API authentication keys |
| `api_rate_limits` | API usage counters |
| `audit_logs` | Activity tracking |
| `settings` | User preferences |
| `user_settings` | User settings backup |
| `tenant_settings` | Tenant settings backup |
| `settings_sync_log` | Settings sync audit trail |
| `marketing_campaigns` | Marketing campaign definitions |
| `marketing_campaign_contacts` | Campaign recipients |
| `marketing_settings` | Tenant marketing limits |
| `marketing_frequency_events` | 30-day frequency tracker |
| `marketing_optouts` | Opt-out blacklist |

---

## 📋 Table Definitions

### `sms_gateway.users`
```sql
CREATE TABLE sms_gateway.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email VARCHAR(255),
  name VARCHAR(255),
  phone_number VARCHAR(20),
  role VARCHAR(50) DEFAULT 'user',
  tenant_id UUID NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### `sms_gateway.contacts`
```sql
CREATE TABLE sms_gateway.contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  tenant_id UUID NOT NULL,
  name VARCHAR(255) NOT NULL,
  phone_number VARCHAR(20) NOT NULL,
  first_name VARCHAR(255),
  last_name VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### `sms_gateway.groups`
```sql
CREATE TABLE sms_gateway.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  tenant_id UUID NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### `sms_gateway.group_members`
```sql
CREATE TABLE sms_gateway.group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES sms_gateway.groups(id),
  contact_id UUID NOT NULL REFERENCES sms_gateway.contacts(id),
  tenant_id UUID NOT NULL,
  added_at TIMESTAMP DEFAULT NOW()
);
```

### `sms_gateway.sms_logs`
```sql
CREATE TABLE sms_gateway.sms_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  tenant_id UUID NOT NULL,
  contact_id UUID REFERENCES sms_gateway.contacts(id),
  phone_number VARCHAR(20) NOT NULL,
  message TEXT NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  sent_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  campaign_id UUID REFERENCES sms_gateway.marketing_campaigns(id),
  channel VARCHAR(50) DEFAULT 'manual',
  device_id VARCHAR(255)
);
```

### `sms_gateway.api_keys`
```sql
CREATE TABLE sms_gateway.api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  tenant_id UUID NOT NULL,
  name VARCHAR(255) NOT NULL,
  key_hash VARCHAR(255) UNIQUE NOT NULL,
  last_used TIMESTAMP WITH TIME ZONE,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### `sms_gateway.api_rate_limits`
```sql
CREATE TABLE sms_gateway.api_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  api_key_id UUID NOT NULL REFERENCES sms_gateway.api_keys(id),
  window_start TIMESTAMP WITH TIME ZONE NOT NULL,
  request_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### `sms_gateway.sms_requests`
```sql
CREATE TABLE sms_gateway.sms_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  api_key_id UUID REFERENCES sms_gateway.api_keys(id),
  phone_number VARCHAR(20) NOT NULL,
  message TEXT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  priority INTEGER DEFAULT 0,
  scheduled_at TIMESTAMP WITH TIME ZONE,
  processed_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  external_id VARCHAR(255),
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  source VARCHAR(50) DEFAULT 'api',
  created_by UUID
);
```

### `sms_gateway.tenants`
```sql
CREATE TABLE sms_gateway.tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  client_id UUID
);
```

### `sms_gateway.tenant_members`
```sql
CREATE TABLE sms_gateway.tenant_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  role TEXT NOT NULL DEFAULT 'member',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
```

### `sms_gateway.settings`
```sql
CREATE TABLE sms_gateway.settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES sms_gateway.users(id),
  setting_key VARCHAR(255) NOT NULL,
  setting_value JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  tenant_id UUID NOT NULL
);
```

### `sms_gateway.marketing_campaigns`
```sql
CREATE TABLE sms_gateway.marketing_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id),
  name VARCHAR(255) NOT NULL,
  message_template TEXT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'draft',
  daily_sent_count INTEGER NOT NULL DEFAULT 0,
  total_sent_count INTEGER NOT NULL DEFAULT 0,
  total_contact_count INTEGER NOT NULL DEFAULT 0,
  created_by UUID REFERENCES sms_gateway.users(id),
  created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  activated_at TIMESTAMP WITHOUT TIME ZONE,
  paused_at TIMESTAMP WITHOUT TIME ZONE,
  completed_at TIMESTAMP WITHOUT TIME ZONE,
  updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
```

### `sms_gateway.marketing_campaign_contacts`
```sql
CREATE TABLE sms_gateway.marketing_campaign_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES sms_gateway.marketing_campaigns(id),
  contact_id UUID REFERENCES sms_gateway.contacts(id),
  phone_number VARCHAR(20) NOT NULL,
  first_name VARCHAR(255),
  last_name VARCHAR(255),
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  sent_at TIMESTAMP WITHOUT TIME ZONE,
  failure_reason TEXT,
  created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
```

### `sms_gateway.marketing_settings`
```sql
CREATE TABLE sms_gateway.marketing_settings (
  tenant_id UUID PRIMARY KEY REFERENCES sms_gateway.tenants(id),
  enabled BOOLEAN NOT NULL DEFAULT false,
  daily_limit INTEGER NOT NULL DEFAULT 100,
  per_number_limit INTEGER NOT NULL DEFAULT 2,
  per_number_days INTEGER NOT NULL DEFAULT 30,
  send_interval_seconds INTEGER NOT NULL DEFAULT 45,
  daily_sent_count INTEGER NOT NULL DEFAULT 0,
  last_reset_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
```

### `sms_gateway.marketing_frequency_events`
```sql
CREATE TABLE sms_gateway.marketing_frequency_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id),
  phone_number VARCHAR(20) NOT NULL,
  campaign_id UUID REFERENCES sms_gateway.marketing_campaigns(id),
  sent_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  message_preview TEXT,
  device_id VARCHAR(255)
);
```

### `sms_gateway.marketing_optouts`
```sql
CREATE TABLE sms_gateway.marketing_optouts (
  phone_number VARCHAR(20) NOT NULL,
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id),
  opted_out_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
  method VARCHAR(50) NOT NULL DEFAULT 'manual',
  notes TEXT,
  added_by UUID REFERENCES sms_gateway.users(id),
  PRIMARY KEY (phone_number, tenant_id)
);
```

### `sms_gateway.user_settings` (Settings Backup)
```sql
CREATE TABLE sms_gateway.user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
  
  -- SMS Preferences
  sms_channel TEXT DEFAULT 'thisPhone' CHECK (sms_channel IN ('thisPhone', 'quickSMS')),
  api_queue_auto_start BOOLEAN DEFAULT false,
  
  -- UI Preferences
  theme_mode TEXT DEFAULT 'light' CHECK (theme_mode IN ('light', 'dark', 'system')),
  language TEXT DEFAULT 'en',
  
  -- Notification Preferences
  notification_on_sms_sent BOOLEAN DEFAULT true,
  notification_on_sms_failed BOOLEAN DEFAULT true,
  notification_on_quota_warning BOOLEAN DEFAULT true,
  
  -- Additional settings (JSON for extensibility)
  additional_settings JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  synced_at TIMESTAMP WITH TIME ZONE,
  
  UNIQUE(user_id, tenant_id)
);
```

### `sms_gateway.tenant_settings` (Settings Backup)
```sql
CREATE TABLE sms_gateway.tenant_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL UNIQUE REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
  
  -- Default SMS Settings
  default_sms_channel TEXT DEFAULT 'thisPhone' CHECK (default_sms_channel IN ('thisPhone', 'quickSMS')),
  default_sms_sender_id TEXT,
  
  -- Quota Settings
  daily_sms_quota INTEGER DEFAULT 10000,
  monthly_sms_quota INTEGER DEFAULT 100000,
  
  -- Feature Flags
  enable_bulk_sms BOOLEAN DEFAULT true,
  enable_scheduled_sms BOOLEAN DEFAULT true,
  enable_sms_groups BOOLEAN DEFAULT true,
  enable_api_access BOOLEAN DEFAULT true,
  
  -- API Settings
  api_webhook_url TEXT,
  api_webhook_secret TEXT,
  
  -- Billing & Plan Info
  plan_type TEXT DEFAULT 'basic' CHECK (plan_type IN ('basic', 'pro', 'enterprise')),
  sms_cost_per_unit NUMERIC(10, 4) DEFAULT 0.05,
  
  -- Advanced Settings
  advanced_settings JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  synced_at TIMESTAMP WITH TIME ZONE,
  
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);
```

### `sms_gateway.settings_sync_log` (Settings Backup Audit Trail)
```sql
CREATE TABLE sms_gateway.settings_sync_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
  
  sync_type TEXT NOT NULL CHECK (sync_type IN ('user_settings', 'tenant_settings', 'both')),
  direction TEXT NOT NULL CHECK (direction IN ('local_to_remote', 'remote_to_local', 'bidirectional')),
  
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'partial')),
  error_message TEXT,
  
  settings_count INTEGER DEFAULT 0,
  synced_fields TEXT[], -- Array of field names that were synced
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE
);
```

---

## ⚙️ Settings Backup System

### Overview
The settings backup system allows users to:
- **Backup** their user preferences to Supabase (SMS channel, theme, language, notifications)
- **Backup** tenant-wide settings (quotas, feature flags, plan type)
- **Restore** settings on different devices for cross-device sync
- **Track** all sync operations in audit trail

### How It Works

#### User Settings Backup Flow
1. User clicks "Backup Settings to Supabase" in Settings screen
2. `SettingsBackupService` reads local SharedPreferences
3. Calls RPC function `update_user_settings()` 
4. Creates entry in `settings_sync_log` with status='pending'
5. If successful, marks log entry with status='success'
6. If error, stores error message in log

#### Tenant Settings Backup Flow
1. Tenant admin clicks "Backup Settings to Supabase"
2. `SettingsBackupService` reads tenant settings from SharedPreferences
3. Upserts into `tenant_settings` table via REST API
4. Creates audit log entry in `settings_sync_log`
5. Marks as success/failed based on result

#### Cross-Device Restore Flow
1. User logs in on new device
2. Clicks "Restore Settings from Supabase"
3. `SettingsBackupService` calls `get_user_settings()` RPC
4. Fetches from `user_settings` table
5. Writes all values to local SharedPreferences
6. Logs the restore operation
7. All user preferences now match previous device

### RPC Functions

#### `get_user_settings(p_user_id, p_tenant_id)`
Fetches user settings with RLS applied.
```dart
final response = await supabase.rpc('get_user_settings', params: {
  'p_user_id': userId,
  'p_tenant_id': tenantId,
});
```

#### `update_user_settings(...)`
Upserts user settings (insert if new, update if exists).
```dart
await supabase.rpc('update_user_settings', params: {
  'p_user_id': userId,
  'p_tenant_id': tenantId,
  'p_sms_channel': 'thisPhone',
  'p_api_queue_auto_start': true,
  'p_theme_mode': 'dark',
  'p_language': 'en',
  // ... other settings
});
```

#### `get_tenant_settings(p_tenant_id)`
Fetches tenant settings.

#### `log_settings_sync(...)`
Creates sync log entry for audit trail.

#### `complete_settings_sync(p_log_id, p_status)`
Marks sync operation as completed.

### RLS Policies for Settings Tables

**User Settings:**
- Users can only view their own settings
- Users can only update their own settings
- Tenant members can see settings for their tenant

**Tenant Settings:**
- Tenant members can view settings
- Only admins/owners can update settings
- Prevents regular members from changing workspace config

**Sync Log:**
- Users can view their own sync logs
- Admins can view all sync logs for their tenant
- Complete audit trail of all operations

---

## 🔐 Row Level Security (RLS)

All tables have RLS enabled with policies that enforce:
1. **User Ownership** - Users can only access their own data
2. **Tenant Isolation** - Data is filtered by `tenant_id`
3. **Product Access** - Verified via `client_product_access`

### Example Policy
```sql
-- Users can only view their own contacts in their tenant
CREATE POLICY "Users can view own contacts"
  ON sms_gateway.contacts FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    AND tenant_id IN (
      SELECT tenant_id FROM public.client_product_access
      WHERE user_id = auth.uid()
      AND product_id = (SELECT id FROM public.products WHERE schema_name = 'sms_gateway')
    )
  );
```

---

## 🔄 Multi-Tenant Flow

### Authentication Flow
```
1. User logs in (Supabase Auth)
   ↓
2. Check auth.users (password verification)
   ↓
3. Load public.client_product_access (get tenant list)
   ↓
4. Load sms_gateway.users (product profile)
   ↓
5. If 1 tenant → Auto-select
   If 2+ tenants → Show picker
```

### Query Pattern
```dart
// All queries must include tenant_id
final contacts = await supabase
    .from('sms_gateway.contacts')
    .select()
    .eq('user_id', userId)
    .eq('tenant_id', tenantId);  // Required!
```

---

## 📊 Helper Functions

### `public.create_client`
Creates a new organization/client.
```sql
SELECT public.create_client(
  p_owner_id := 'user-uuid',
  p_client_name := 'My Company',
  p_client_slug := 'my-company',
  p_client_email := 'admin@company.com',
  p_owner_name := 'John Doe',
  p_owner_email := 'john@company.com'
);
```

### `public.subscribe_client_to_product`
Subscribes a client to SMS Gateway and creates a tenant.
```sql
SELECT public.subscribe_client_to_product(
  p_client_id := 'client-uuid',
  p_product_schema := 'sms_gateway',
  p_tenant_name := 'SMS Workspace',
  p_tenant_slug := 'sms-workspace',
  p_plan_type := 'pro'
);
```

### `public.add_user_to_client_product`
Adds a user to a client's product tenant.
```sql
SELECT public.add_user_to_client_product(
  p_user_id := 'user-uuid',
  p_client_id := 'client-uuid',
  p_product_schema := 'sms_gateway',
  p_tenant_id := 'tenant-uuid',
  p_role := 'admin',
  p_user_email := 'user@company.com',
  p_user_name := 'Jane Smith'
);
```

---

## 🛠️ Supabase CLI Commands

### Link to Remote
```bash
npx supabase link --project-ref kzjgdeqfmxkmpmadtbpb
```

### Pull Remote Schema
```bash
npx supabase db pull
```

### Push Migrations
```bash
npx supabase db push
```

### Create New Migration
```bash
npx supabase migration new <migration_name>
```

### List Migrations
```bash
npx supabase migration list
```

---

## 📁 Migration Files

Located in `supabase/migrations/`:

| File | Description |
|------|-------------|
| `20251222223134_remote_schema.sql` | Current production schema |

---

## ⚠️ Important Notes

1. **Schema Prefix Required**
   ```dart
   // ✅ Correct
   .from('sms_gateway.contacts')
   
   // ❌ Wrong
   .from('contacts')
   ```

2. **Always Include tenant_id**
   ```dart
   // ✅ Correct
   .eq('tenant_id', tenantId)
   .eq('user_id', userId)
   ```

3. **Exposed Schemas**
   - In Supabase Dashboard → Settings → API
   - Ensure `sms_gateway` is in exposed schemas list

4. **RLS Must Be Enabled**
   - All tables have RLS enabled by default
   - Never disable RLS in production

---

## 🔍 Verification Queries

### Check Schema Exists
```sql
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name = 'sms_gateway';
```

### Check Tables Have tenant_id
```sql
SELECT table_name, column_name 
FROM information_schema.columns 
WHERE table_schema = 'sms_gateway' 
AND column_name = 'tenant_id';
```

### Check RLS Enabled
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'sms_gateway';
```

### Check Policies
```sql
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'sms_gateway';
```

---

## 📞 Sender ID Management Feature

### Overview
The Sender ID Management feature allows customers to request custom Sender IDs for their SMS messages. A Sender ID is the name that appears as the sender of an SMS (e.g., "MYBANK", "ACME", "ALERT").

### Database Schema: `sender_id_requests`

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `tenant_id` | uuid | Tenant who requested |
| `user_id` | uuid | User who submitted request |
| `sender_id` | varchar(11) | Requested Sender ID (max 11 alphanumeric) |
| `business_name` | varchar(255) | Business name |
| `purpose` | text | Purpose of use |
| `contact_phone` | varchar(20) | Contact number |
| `status` | varchar(20) | pending/approved/rejected/active |
| `admin_notes` | text | Admin comments |
| `reviewed_by` | uuid | Admin who reviewed |
| `reviewed_at` | timestamp | Review timestamp |
| `created_at` | timestamp | Request creation time |
| `updated_at` | timestamp | Last update time |

### User Flow

1. **Request Sender ID**: Navigate to Settings → Sender ID Management
2. **Admin Review**: Request goes to admin for approval (1-2 business days)
3. **Status Updates**: pending → approved → active
4. **Use Sender ID**: Once active, configure in SMS settings

### Setup

Run migration in Supabase SQL Editor:
```sql
-- See database/sender_id_requests_table.sql
CREATE TABLE sms_gateway.sender_id_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
  user_id uuid REFERENCES sms_gateway.users(id) ON DELETE SET NULL,
  sender_id varchar(11) NOT NULL,
  business_name varchar(255) NOT NULL,
  purpose text NOT NULL,
  contact_phone varchar(20) NOT NULL,
  status varchar(20) DEFAULT 'pending',
  admin_notes text,
  reviewed_by uuid,
  reviewed_at timestamp,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

-- Enable RLS
ALTER TABLE sms_gateway.sender_id_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their tenant's requests
CREATE POLICY "Users can view tenant sender ID requests"
  ON sms_gateway.sender_id_requests FOR SELECT
  USING (tenant_id IN (
    SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
  ));

-- Policy: Users can create requests for their tenant
CREATE POLICY "Users can create sender ID requests"
  ON sms_gateway.sender_id_requests FOR INSERT
  WITH CHECK (tenant_id IN (
    SELECT tenant_id FROM sms_gateway.tenant_members WHERE user_id = auth.uid()
  ));
```

### Technical Notes
- Sender IDs limited to 11 characters (telecom standard)
- Alphanumeric only (A-Z, 0-9)
- Case-insensitive (stored as uppercase)
- Requires admin approval for security
- RLS ensures tenant isolation

---

## 📞 Support

For database issues:
1. Check Supabase Dashboard logs
2. Verify RLS policies
3. Check schema exposure settings
4. Review migration history
