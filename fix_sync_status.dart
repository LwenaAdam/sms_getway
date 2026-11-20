// One-time script to fix sync status for all contacts
// Run with: flutter run -d linux -t fix_sync_status.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/database/app_database.dart';
import 'lib/core/tenant_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (get your keys from environment)
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  
  
  final db = AppDatabase.instance;
  final tenantId = TenantService().tenantId;
  
  if (tenantId == null) {
    return;
  }
  
  // Get all pending contacts
  final pending = await db.getPendingContacts(tenantId);
  
  // Mark them all as synced
  final ids = pending.map((c) => c.id).toList();
  await db.markContactsSynced(ids);
  
}
