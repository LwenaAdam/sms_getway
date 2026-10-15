# Fix Registration RLS Policies - Quick Guide

## Problem
Users getting error during registration:
```
PostgresException: new row violates row-level security policy for table 'tenants'
```

## Solution
Run the SQL script to fix RLS policies for all registration tables.

## Steps:

### 1. Open Supabase SQL Editor
Go to: https://supabase.com/dashboard/project/kzjgdeqfmxkmpmadtbpb/sql/new

### 2. Copy the SQL Script
The complete fix is in: `database/migrations/fix_all_registration_rls_policies.sql`

### 3. Run the Script
- Paste the entire contents into the SQL editor
- Click "Run" button
- Wait for success message

### 4. Verify
After running, you should see:
- ✅ All RLS policies for registration have been updated successfully
- ✅ Users can now complete the registration process

### 5. Test Registration
Try registering a new user in the app. The error should be gone!

## What This Fixes:
- ✅ `sms_gateway.tenants` - Allows tenant creation during registration
- ✅ `sms_gateway.users` - Allows user profile creation
- ✅ `sms_gateway.tenant_members` - Allows membership creation
- ✅ `sms_gateway.user_settings` - Allows user settings creation
- ✅ `sms_gateway.tenant_settings` - Allows tenant settings creation
- ✅ `public.clients` - Allows client/organization creation
- ✅ `public.client_product_access` - Allows product access creation

## Affected Tables:
All tables used during the registration flow are now properly configured.
