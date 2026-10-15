-- Auto-recover ALL incomplete registrations (FIXED)
-- This script automatically completes registration for all users who failed
-- Run this to recover everyone at once

DO $$
DECLARE
  v_user RECORD;
  v_client_id UUID;
  v_tenant_id UUID;
  v_product_id UUID;
  v_recovered_count INT := 0;
  v_error_count INT := 0;
BEGIN
  
  RAISE NOTICE '🔍 Scanning for incomplete registrations...';
  RAISE NOTICE '';
  
  -- Try to get SMS Gateway product ID (check by name or just get first product)
  SELECT id INTO v_product_id
  FROM public.products
  WHERE name ILIKE '%sms%gateway%' OR name ILIKE '%sms%'
  LIMIT 1;
  
  IF v_product_id IS NULL THEN
    -- If no SMS product found, just get the first product
    SELECT id INTO v_product_id FROM public.products LIMIT 1;
  END IF;
  
  -- Loop through all auth users without complete profiles
  FOR v_user IN (
    SELECT DISTINCT
      au.id as user_id,
      au.email,
      COALESCE(
        au.raw_user_meta_data->>'full_name',
        au.raw_user_meta_data->>'name',
        SPLIT_PART(au.email, '@', 1)
      ) as name,
      COALESCE(
        au.raw_user_meta_data->>'phone',
        au.raw_user_meta_data->>'phone_number',
        ''
      ) as phone,
      c.id as existing_client_id,
      COALESCE(c.name, SPLIT_PART(au.email, '@', 1) || '''s Organization') as org_name,
      COALESCE(c.slug, REPLACE(LOWER(SPLIT_PART(au.email, '@', 1)), ' ', '-')) as org_slug,
      t.id as existing_tenant_id
    FROM auth.users au
    LEFT JOIN public.clients c ON c.owner_id = au.id
    LEFT JOIN sms_gateway.tenants t ON t.client_id = c.id
    LEFT JOIN sms_gateway.users u ON u.id = au.id
    WHERE u.id IS NULL  -- No user profile = incomplete registration
      AND au.created_at > NOW() - INTERVAL '90 days'  -- Last 90 days
    ORDER BY au.created_at DESC
  ) LOOP
    
    BEGIN
      RAISE NOTICE '────────────────────────────────────────────────';
      RAISE NOTICE '📧 Recovering: %', v_user.email;
      
      -- STEP 1: Ensure client exists
      IF v_user.existing_client_id IS NULL THEN
        INSERT INTO public.clients (name, slug, email, owner_id, is_active)
        VALUES (v_user.org_name, v_user.org_slug, v_user.email, v_user.user_id, true)
        RETURNING id INTO v_client_id;
        RAISE NOTICE '   ✅ Created client: %', v_user.org_name;
      ELSE
        v_client_id := v_user.existing_client_id;
        RAISE NOTICE '   ✅ Using existing client';
      END IF;
      
      -- STEP 2: Ensure tenant exists
      IF v_user.existing_tenant_id IS NULL THEN
        INSERT INTO sms_gateway.tenants (name, slug, client_id, status)
        VALUES (v_user.org_name, v_user.org_slug, v_client_id, 'active')
        RETURNING id INTO v_tenant_id;
        RAISE NOTICE '   ✅ Created tenant: %', v_user.org_name;
      ELSE
        v_tenant_id := v_user.existing_tenant_id;
        RAISE NOTICE '   ✅ Using existing tenant';
      END IF;
      
      -- STEP 3: Create user profile
      INSERT INTO sms_gateway.users (id, email, name, phone_number, role, tenant_id)
      VALUES (v_user.user_id, v_user.email, v_user.name, v_user.phone, 'owner', v_tenant_id)
      ON CONFLICT (id) DO NOTHING;
      RAISE NOTICE '   ✅ Created user profile';
      
      -- STEP 4: Create tenant membership
      INSERT INTO sms_gateway.tenant_members (user_id, tenant_id, role)
      VALUES (v_user.user_id, v_tenant_id, 'owner')
      ON CONFLICT (user_id, tenant_id) DO NOTHING;
      RAISE NOTICE '   ✅ Created tenant membership';
      
      -- STEP 5: Create user settings
      INSERT INTO sms_gateway.user_settings (
        user_id, theme_mode, notification_enabled, auto_sync_enabled
      )
      VALUES (v_user.user_id, 'system', true, true)
      ON CONFLICT (user_id) DO NOTHING;
      RAISE NOTICE '   ✅ Created user settings';
      
      -- STEP 6: Create tenant settings
      INSERT INTO sms_gateway.tenant_settings (
        tenant_id, max_users, max_contacts, max_sms_per_month, features
      )
      VALUES (
        v_tenant_id, 10, 10000, 10000,
        '{"bulk_sms": true, "api_access": true, "reports": true}'::jsonb
      )
      ON CONFLICT (tenant_id) DO NOTHING;
      RAISE NOTICE '   ✅ Created tenant settings';
      
      -- STEP 7: Create product access (if product exists)
      IF v_product_id IS NOT NULL THEN
        INSERT INTO public.client_product_access (
          client_id, product_id, is_active, access_level
        )
        VALUES (v_client_id, v_product_id, true, 'full')
        ON CONFLICT (client_id, product_id) DO NOTHING;
        RAISE NOTICE '   ✅ Created product access';
      ELSE
        RAISE NOTICE '   ⚠️  No product found - skipping product access';
      END IF;
      
      v_recovered_count := v_recovered_count + 1;
      RAISE NOTICE '   🎉 Recovery complete for %', v_user.email;
      
    EXCEPTION WHEN OTHERS THEN
      v_error_count := v_error_count + 1;
      RAISE NOTICE '   ❌ Error recovering %: %', v_user.email, SQLERRM;
    END;
    
  END LOOP;
  
  -- Final summary
  RAISE NOTICE '';
  RAISE NOTICE '════════════════════════════════════════════════════════';
  RAISE NOTICE '🎉 AUTO-RECOVERY COMPLETE';
  RAISE NOTICE '════════════════════════════════════════════════════════';
  RAISE NOTICE '✅ Successfully recovered: % users', v_recovered_count;
  IF v_error_count > 0 THEN
    RAISE NOTICE '❌ Errors encountered: % users', v_error_count;
  END IF;
  RAISE NOTICE '';
  RAISE NOTICE 'All recovered users can now log in to the application!';
  RAISE NOTICE '════════════════════════════════════════════════════════';
  
END $$;

-- Verify the recovery
SELECT 
  'Total auth users (last 90 days)' as status,
  COUNT(*) as count
FROM auth.users
WHERE created_at > NOW() - INTERVAL '90 days'

UNION ALL

SELECT 
  'Users with complete profiles',
  COUNT(*)
FROM auth.users au
INNER JOIN sms_gateway.users u ON u.id = au.id
WHERE au.created_at > NOW() - INTERVAL '90 days'

UNION ALL

SELECT 
  'Users still incomplete',
  COUNT(*)
FROM auth.users au
LEFT JOIN sms_gateway.users u ON u.id = au.id
WHERE au.created_at > NOW() - INTERVAL '90 days'
  AND u.id IS NULL;
