-- Recover incomplete registration accounts
-- This script completes the registration for users who failed partway through
--
-- INSTRUCTIONS:
-- 1. First run identify_failed_registrations.sql to find users
-- 2. Fill in the variables below with the user's information
-- 3. Run this script to complete their registration

-- =============================================================================
-- CONFIGURATION: Fill in these variables for the user to recover
-- =============================================================================

DO $$
DECLARE
  -- USER INFO (from identify_failed_registrations.sql or auth.users)
  v_user_id UUID := 'PASTE_USER_ID_HERE';  -- From auth.users.id
  v_email TEXT := 'user@example.com';      -- User's email
  v_name TEXT := 'User Name';               -- User's full name
  v_phone TEXT := '+1234567890';            -- User's phone (optional)
  
  -- ORGANIZATION INFO (if exists, get from public.clients)
  v_client_id UUID;
  v_client_name TEXT := 'Organization Name';  -- Default if no client exists
  v_client_slug TEXT := 'org-slug';           -- Default if no client exists
  
  -- IDs to be created/retrieved
  v_tenant_id UUID;
  v_new_client BOOLEAN := FALSE;
  v_new_tenant BOOLEAN := FALSE;

BEGIN
  
  RAISE NOTICE '🔍 Starting recovery for user: %', v_email;
  
  -- =============================================================================
  -- STEP 1: Check and create CLIENT if needed
  -- =============================================================================
  
  -- Check if client exists
  SELECT id INTO v_client_id
  FROM public.clients
  WHERE owner_id = v_user_id
  LIMIT 1;
  
  IF v_client_id IS NULL THEN
    RAISE NOTICE '📝 Creating client organization...';
    
    -- Create client
    INSERT INTO public.clients (name, slug, email, owner_id, is_active)
    VALUES (v_client_name, v_client_slug, v_email, v_user_id, true)
    RETURNING id INTO v_client_id;
    
    v_new_client := TRUE;
    RAISE NOTICE '✅ Client created: %', v_client_id;
  ELSE
    RAISE NOTICE '✅ Client already exists: %', v_client_id;
  END IF;
  
  -- =============================================================================
  -- STEP 2: Check and create TENANT if needed
  -- =============================================================================
  
  -- Check if tenant exists
  SELECT id INTO v_tenant_id
  FROM sms_gateway.tenants
  WHERE client_id = v_client_id
  LIMIT 1;
  
  IF v_tenant_id IS NULL THEN
    RAISE NOTICE '📝 Creating SMS Gateway tenant...';
    
    -- Create tenant
    INSERT INTO sms_gateway.tenants (name, slug, client_id, status)
    VALUES (v_client_name, v_client_slug, v_client_id, 'active')
    RETURNING id INTO v_tenant_id;
    
    v_new_tenant := TRUE;
    RAISE NOTICE '✅ Tenant created: %', v_tenant_id;
  ELSE
    RAISE NOTICE '✅ Tenant already exists: %', v_tenant_id;
  END IF;
  
  -- =============================================================================
  -- STEP 3: Create USER PROFILE if needed
  -- =============================================================================
  
  -- Check if user profile exists
  IF NOT EXISTS (SELECT 1 FROM sms_gateway.users WHERE id = v_user_id) THEN
    RAISE NOTICE '📝 Creating user profile...';
    
    INSERT INTO sms_gateway.users (id, email, name, phone_number, role, tenant_id)
    VALUES (v_user_id, v_email, v_name, v_phone, 'owner', v_tenant_id)
    ON CONFLICT (id) DO NOTHING;
    
    RAISE NOTICE '✅ User profile created';
  ELSE
    RAISE NOTICE '✅ User profile already exists';
  END IF;
  
  -- =============================================================================
  -- STEP 4: Create TENANT MEMBERSHIP if needed
  -- =============================================================================
  
  IF NOT EXISTS (
    SELECT 1 FROM sms_gateway.tenant_members 
    WHERE user_id = v_user_id AND tenant_id = v_tenant_id
  ) THEN
    RAISE NOTICE '📝 Creating tenant membership...';
    
    INSERT INTO sms_gateway.tenant_members (user_id, tenant_id, role)
    VALUES (v_user_id, v_tenant_id, 'owner')
    ON CONFLICT (user_id, tenant_id) DO NOTHING;
    
    RAISE NOTICE '✅ Tenant membership created';
  ELSE
    RAISE NOTICE '✅ Tenant membership already exists';
  END IF;
  
  -- =============================================================================
  -- STEP 5: Create USER SETTINGS if needed
  -- =============================================================================
  
  IF NOT EXISTS (SELECT 1 FROM sms_gateway.user_settings WHERE user_id = v_user_id) THEN
    RAISE NOTICE '📝 Creating user settings...';
    
    INSERT INTO sms_gateway.user_settings (
      user_id, 
      theme_mode, 
      notification_enabled, 
      auto_sync_enabled
    )
    VALUES (v_user_id, 'system', true, true)
    ON CONFLICT (user_id) DO NOTHING;
    
    RAISE NOTICE '✅ User settings created';
  ELSE
    RAISE NOTICE '✅ User settings already exists';
  END IF;
  
  -- =============================================================================
  -- STEP 6: Create TENANT SETTINGS if needed
  -- =============================================================================
  
  IF NOT EXISTS (SELECT 1 FROM sms_gateway.tenant_settings WHERE tenant_id = v_tenant_id) THEN
    RAISE NOTICE '📝 Creating tenant settings...';
    
    INSERT INTO sms_gateway.tenant_settings (
      tenant_id,
      max_users,
      max_contacts,
      max_sms_per_month,
      features
    )
    VALUES (
      v_tenant_id,
      10,
      10000,
      10000,
      '{"bulk_sms": true, "api_access": true, "reports": true}'::jsonb
    )
    ON CONFLICT (tenant_id) DO NOTHING;
    
    RAISE NOTICE '✅ Tenant settings created';
  ELSE
    RAISE NOTICE '✅ Tenant settings already exists';
  END IF;
  
  -- =============================================================================
  -- STEP 7: Create PRODUCT ACCESS if needed
  -- =============================================================================
  
  IF NOT EXISTS (
    SELECT 1 FROM public.client_product_access 
    WHERE client_id = v_client_id
  ) THEN
    RAISE NOTICE '📝 Creating product access...';
    
    -- Get SMS Gateway product ID
    DECLARE
      v_product_id UUID;
    BEGIN
      SELECT id INTO v_product_id
      FROM public.products
      WHERE slug = 'sms_gateway'
      LIMIT 1;
      
      IF v_product_id IS NOT NULL THEN
        INSERT INTO public.client_product_access (
          client_id,
          product_id,
          is_active,
          access_level
        )
        VALUES (v_client_id, v_product_id, true, 'full')
        ON CONFLICT (client_id, product_id) DO NOTHING;
        
        RAISE NOTICE '✅ Product access created';
      ELSE
        RAISE NOTICE '⚠️  SMS Gateway product not found in products table';
      END IF;
    END;
  ELSE
    RAISE NOTICE '✅ Product access already exists';
  END IF;
  
  -- =============================================================================
  -- FINAL SUMMARY
  -- =============================================================================
  
  RAISE NOTICE '';
  RAISE NOTICE '════════════════════════════════════════════════════════';
  RAISE NOTICE '🎉 RECOVERY COMPLETE FOR: %', v_email;
  RAISE NOTICE '════════════════════════════════════════════════════════';
  RAISE NOTICE 'User ID: %', v_user_id;
  RAISE NOTICE 'Client ID: % %', v_client_id, CASE WHEN v_new_client THEN '(NEW)' ELSE '' END;
  RAISE NOTICE 'Tenant ID: % %', v_tenant_id, CASE WHEN v_new_tenant THEN '(NEW)' ELSE '' END;
  RAISE NOTICE '';
  RAISE NOTICE '✅ User can now log in to the application';
  RAISE NOTICE '════════════════════════════════════════════════════════';
  
END $$;
