-- Simple recovery script with better error visibility
-- This will show exactly what's happening for each user

DO $$
DECLARE
  v_user RECORD;
  v_client_id UUID;
  v_tenant_id UUID;
  v_product_id UUID;
  v_success INT := 0;
  v_errors INT := 0;
BEGIN
  
  -- Get product
  SELECT id INTO v_product_id FROM public.products WHERE schema_name = 'sms_gateway' LIMIT 1;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Starting recovery process...';
  RAISE NOTICE 'Product ID: %', COALESCE(v_product_id::text, 'NOT FOUND');
  RAISE NOTICE '========================================';
  
  FOR v_user IN (
    SELECT au.id, au.email, c.id as cid, c.name as cname, c.slug as cslug
    FROM auth.users au
    LEFT JOIN public.clients c ON c.owner_id = au.id
    LEFT JOIN sms_gateway.users u ON u.id = au.id
    WHERE u.id IS NULL AND au.created_at > NOW() - INTERVAL '90 days'
    ORDER BY au.created_at DESC
  ) LOOP
    
    RAISE NOTICE '';
    RAISE NOTICE '--- User: %', v_user.email;
    
    BEGIN
      v_client_id := v_user.cid;
      RAISE NOTICE 'Client ID: %', v_client_id;
      
      -- Create tenant
      INSERT INTO sms_gateway.tenants (name, slug, client_id, status)
      VALUES (
        v_user.cname,
        v_user.cslug || '-' || substring(v_user.id::text, 1, 8),
        v_client_id,
        'active'
      )
      RETURNING id INTO v_tenant_id;
      RAISE NOTICE 'Created tenant: %', v_tenant_id;
      
      -- Create user profile
      INSERT INTO sms_gateway.users (id, email, name, role, tenant_id)
      VALUES (v_user.id, v_user.email, SPLIT_PART(v_user.email, '@', 1), 'owner', v_tenant_id);
      RAISE NOTICE 'Created user profile';
      
      -- Create membership
      INSERT INTO sms_gateway.tenant_members (user_id, tenant_id, role)
      VALUES (v_user.id, v_tenant_id, 'owner');
      RAISE NOTICE 'Created membership';
      
      -- Create settings
      INSERT INTO sms_gateway.user_settings (user_id, theme_mode, notification_enabled, auto_sync_enabled)
      VALUES (v_user.id, 'system', true, true);
      RAISE NOTICE 'Created user settings';
      
      INSERT INTO sms_gateway.tenant_settings (tenant_id, max_users, max_contacts, max_sms_per_month, features)
      VALUES (v_tenant_id, 10, 10000, 10000, '{"bulk_sms": true}'::jsonb);
      RAISE NOTICE 'Created tenant settings';
      
      -- Product access
      IF v_product_id IS NOT NULL THEN
        INSERT INTO public.client_product_access (user_id, client_id, product_id, tenant_id, role)
        VALUES (v_user.id, v_client_id, v_product_id, v_tenant_id, 'owner');
        RAISE NOTICE 'Created product access';
      END IF;
      
      -- Global user
      INSERT INTO public.global_users (id, email, name, client_id, role, is_client_owner)
      VALUES (v_user.id, v_user.email, SPLIT_PART(v_user.email, '@', 1), v_client_id, 'admin', true)
      ON CONFLICT (id) DO NOTHING;
      RAISE NOTICE 'Created global user';
      
      v_success := v_success + 1;
      RAISE NOTICE '✅ SUCCESS for %', v_user.email;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE NOTICE '❌ ERROR for %: %', v_user.email, SQLERRM;
    END;
    
  END LOOP;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Recovery complete!';
  RAISE NOTICE 'Success: %', v_success;
  RAISE NOTICE 'Errors: %', v_errors;
  RAISE NOTICE '========================================';
  
END $$;
