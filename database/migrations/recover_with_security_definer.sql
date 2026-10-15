-- Recovery function with SECURITY DEFINER to bypass RLS/context issues
-- This runs with the creator's privileges (service role)

-- Drop function if exists
DROP FUNCTION IF EXISTS recover_incomplete_users();

-- Create the recovery function
CREATE OR REPLACE FUNCTION recover_incomplete_users()
RETURNS TABLE(
  user_email TEXT,
  status TEXT,
  details TEXT
) 
SECURITY DEFINER
SET search_path = public, sms_gateway, auth
LANGUAGE plpgsql
AS $$
DECLARE
  v_user RECORD;
  v_client_id UUID;
  v_tenant_id UUID;
  v_product_id UUID;
  v_result_email TEXT;
  v_result_status TEXT;
  v_result_details TEXT;
BEGIN
  
  -- Get product
  SELECT id INTO v_product_id FROM public.products WHERE schema_name = 'sms_gateway' LIMIT 1;
  
  IF v_product_id IS NULL THEN
    v_result_email := 'SYSTEM';
    v_result_status := 'ERROR';
    v_result_details := 'Product sms_gateway not found';
    RETURN NEXT;
    RETURN;
  END IF;
  
  -- Loop through incomplete users
  FOR v_user IN (
    SELECT 
      au.id, 
      au.email, 
      c.id as client_id, 
      c.name as client_name, 
      c.slug as client_slug,
      au.created_at
    FROM auth.users au
    JOIN public.clients c ON c.owner_id = au.id
    LEFT JOIN sms_gateway.users u ON u.id = au.id
    WHERE u.id IS NULL 
      AND au.created_at > NOW() - INTERVAL '90 days'
    ORDER BY au.created_at DESC
  ) LOOP
    
    BEGIN
      v_client_id := v_user.client_id;
      v_result_email := v_user.email;
      
      -- Create tenant
      INSERT INTO sms_gateway.tenants (name, slug, client_id, status)
      VALUES (
        v_user.client_name,
        v_user.client_slug || '-' || substring(v_user.id::text, 1, 8),
        v_client_id,
        'active'
      )
      RETURNING id INTO v_tenant_id;
      
      -- Create user profile
      INSERT INTO sms_gateway.users (id, email, name, role, tenant_id)
      VALUES (
        v_user.id, 
        v_user.email, 
        COALESCE(SPLIT_PART(v_user.email, '@', 1), 'User'), 
        'owner', 
        v_tenant_id
      );
      
      -- Create membership
      INSERT INTO sms_gateway.tenant_members (user_id, tenant_id, role)
      VALUES (v_user.id, v_tenant_id, 'owner');
      
      -- Create user settings
      INSERT INTO sms_gateway.user_settings (user_id, theme_mode, notification_enabled, auto_sync_enabled)
      VALUES (v_user.id, 'system', true, true)
      ON CONFLICT (user_id) DO NOTHING;
      
      -- Create tenant settings
      INSERT INTO sms_gateway.tenant_settings (tenant_id, max_users, max_contacts, max_sms_per_month, features)
      VALUES (v_tenant_id, 10, 10000, 10000, '{"bulk_sms": true}'::jsonb)
      ON CONFLICT (tenant_id) DO NOTHING;
      
      -- Product access
      INSERT INTO public.client_product_access (user_id, client_id, product_id, tenant_id, role)
      VALUES (v_user.id, v_client_id, v_product_id, v_tenant_id, 'owner')
      ON CONFLICT (user_id, client_id, product_id) DO NOTHING;
      
      -- Global user
      INSERT INTO public.global_users (id, email, name, client_id, role, is_client_owner)
      VALUES (
        v_user.id, 
        v_user.email, 
        COALESCE(SPLIT_PART(v_user.email, '@', 1), 'User'), 
        v_client_id, 
        'admin', 
        true
      )
      ON CONFLICT (id) DO NOTHING;
      
      -- Product subscription
      INSERT INTO public.product_subscriptions (product_id, client_id, tenant_id, status, subscription_type, start_date)
      VALUES (v_product_id, v_client_id, v_tenant_id, 'active', 'standard', NOW())
      ON CONFLICT DO NOTHING;
      
      v_result_status := 'SUCCESS';
      v_result_details := format('Created tenant %s', v_tenant_id);
      RETURN NEXT;
      
    EXCEPTION WHEN OTHERS THEN
      v_result_status := 'ERROR';
      v_result_details := SQLERRM;
      RETURN NEXT;
    END;
    
  END LOOP;
  
  RETURN;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION recover_incomplete_users() TO authenticated;
GRANT EXECUTE ON FUNCTION recover_incomplete_users() TO service_role;

-- Execute the recovery
SELECT * FROM recover_incomplete_users();

-- Verify results
SELECT 
  'Verification' as step,
  COUNT(*) FILTER (WHERE u.id IS NOT NULL) as complete_users,
  COUNT(*) FILTER (WHERE u.id IS NULL) as incomplete_users
FROM auth.users au
LEFT JOIN sms_gateway.users u ON u.id = au.id
WHERE au.created_at > NOW() - INTERVAL '90 days';
