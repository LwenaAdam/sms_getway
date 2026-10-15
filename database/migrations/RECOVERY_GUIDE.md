# Failed Registration Recovery Guide

## Problem
Users who tried to register but encountered RLS policy errors are stuck with auth accounts but no profiles.

## Solution Scripts

### 1️⃣ **identify_failed_registrations.sql**
**Purpose:** Find all users with incomplete registrations

**What it shows:**
- Users who have auth accounts but no complete profiles
- Missing components (client, tenant, user profile)
- Detailed breakdown by registration status

**Run this first to see who needs help!**

---

### 2️⃣ **auto_recover_all_failed_registrations.sql** ⭐ RECOMMENDED
**Purpose:** Automatically recover ALL incomplete registrations at once

**What it does:**
- Finds all users without complete profiles (last 90 days)
- Creates missing components:
  - ✅ Client/Organization
  - ✅ Tenant
  - ✅ User profile
  - ✅ Tenant membership
  - ✅ User settings
  - ✅ Tenant settings
  - ✅ Product access
- Shows progress for each user
- Provides final summary

**Use this to recover everyone automatically!**

---

### 3️⃣ **recover_failed_registration.sql**
**Purpose:** Manually recover a single user

**When to use:**
- You want to recover just one specific user
- You want more control over the recovery process

**How to use:**
1. Get user details from `identify_failed_registrations.sql`
2. Edit the variables at the top:
   ```sql
   v_user_id UUID := 'paste-uuid-here';
   v_email TEXT := 'user@example.com';
   v_name TEXT := 'User Name';
   v_phone TEXT := '+1234567890';
   v_client_name TEXT := 'Organization Name';
   v_client_slug TEXT := 'org-slug';
   ```
3. Run the script

---

## 🚀 Quick Start (Recommended Process)

### Step 1: Fix RLS Policies
```sql
-- Run this first (already done if registration works now)
-- File: fix_tenant_circular_dependency.sql
```

### Step 2: Identify Failed Users
```sql
-- See who needs recovery
-- File: identify_failed_registrations.sql
```

### Step 3: Recover Everyone
```sql
-- Auto-recover all incomplete registrations
-- File: auto_recover_all_failed_registrations.sql
```

### Step 4: Verify
Check that all users now have complete profiles and can log in!

---

## What Gets Created for Each User

| Component | Table | Description |
|-----------|-------|-------------|
| Client | `public.clients` | Top-level organization |
| Tenant | `sms_gateway.tenants` | SMS Gateway product instance |
| User Profile | `sms_gateway.users` | User's profile with role='owner' |
| Membership | `sms_gateway.tenant_members` | User's tenant membership |
| User Settings | `sms_gateway.user_settings` | User preferences (theme, notifications) |
| Tenant Settings | `sms_gateway.tenant_settings` | Org limits and features |
| Product Access | `public.client_product_access` | Access to SMS Gateway product |

---

## Example Output

```
🔍 Scanning for incomplete registrations...

────────────────────────────────────────────────
📧 Recovering: user@example.com
   ✅ Created client: User's Organization
   ✅ Created tenant: User's Organization
   ✅ Created user profile
   ✅ Created tenant membership
   ✅ Created user settings
   ✅ Created tenant settings
   ✅ Created product access
   🎉 Recovery complete for user@example.com

════════════════════════════════════════════════════════
🎉 AUTO-RECOVERY COMPLETE
════════════════════════════════════════════════════════
✅ Successfully recovered: 5 users
❌ Errors encountered: 0 users

All recovered users can now log in to the application!
════════════════════════════════════════════════════════
```

---

## Notes

- Scripts use `ON CONFLICT DO NOTHING` to avoid errors if components already exist
- Recovery creates default settings (can be customized by user later)
- All recovered users get 'owner' role for their organization
- Scripts only process users from last 90 days (adjustable)
- Safe to run multiple times - won't duplicate data

---

## Support

If recovery fails for a specific user:
1. Check the error message
2. Manually inspect their auth.users record
3. Use the manual recovery script with custom values
4. Check for database constraints or unique key violations
