/// Settings Backup Service
/// Handles synchronization of user and tenant settings between local (SharedPreferences)
/// and remote (Supabase) storage for backup and cross-device sync
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsBackupService extends ChangeNotifier {
  static final SettingsBackupService _instance =
      SettingsBackupService._internal();

  factory SettingsBackupService() {
    return _instance;
  }

  SettingsBackupService._internal();

  final _supabase = Supabase.instance.client;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  String? _lastSyncStatus;
  String? get lastSyncStatus => _lastSyncStatus;

  // ============================================================================
  // USER SETTINGS BACKUP
  // ============================================================================

  /// Backup user settings to Supabase
  Future<bool> backupUserSettings({
    required String userId,
    required String tenantId,
  }) async {
    try {
      _isSyncing = true;
      notifyListeners();

      debugPrint('🔄 Backing up user settings to Supabase...');

      // Get local user settings
      final prefs = await SharedPreferences.getInstance();
      final userSettings = {
        'sms_channel': prefs.getString('sms_channel') ?? 'thisPhone',
        'api_queue_auto_start': prefs.getBool('api_queue_auto_start') ?? false,
        'theme_mode': prefs.getString('theme_mode') ?? 'light',
        'language': prefs.getString('language') ?? 'en',
        'notification_on_sms_sent':
            prefs.getBool('notification_on_sms_sent') ?? true,
        'notification_on_sms_failed':
            prefs.getBool('notification_on_sms_failed') ?? true,
        'notification_on_quota_warning':
            prefs.getBool('notification_on_quota_warning') ?? true,
      };

      // Log the sync operation
      final syncLogId = await _logSync(
        userId: userId,
        tenantId: tenantId,
        syncType: 'user_settings',
        direction: 'local_to_remote',
      );

      // Call Supabase RPC function to update user settings
      await _supabase.schema('sms_gateway').rpc(
        'update_user_settings',
        params: {
          'p_user_id': userId,
          'p_tenant_id': tenantId,
          'p_sms_channel': userSettings['sms_channel'],
          'p_api_queue_auto_start': userSettings['api_queue_auto_start'],
          'p_theme_mode': userSettings['theme_mode'],
          'p_language': userSettings['language'],
          'p_notification_on_sms_sent':
              userSettings['notification_on_sms_sent'],
          'p_notification_on_sms_failed':
              userSettings['notification_on_sms_failed'],
          'p_notification_on_quota_warning':
              userSettings['notification_on_quota_warning'],
        },
      );

      // Mark sync as successful
      await _completeSync(syncLogId, 'success');

      _lastSyncTime = DateTime.now();
      _lastSyncStatus = '✅ User settings backed up successfully';

      debugPrint('✅ User settings backed up: ${userSettings.length} settings');
      notifyListeners();

      return true;
    } catch (e) {
      _lastSyncStatus = '❌ Error backing up user settings: $e';
      debugPrint(_lastSyncStatus);
      notifyListeners();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Restore user settings from Supabase
  Future<bool> restoreUserSettings({
    required String userId,
    required String tenantId,
  }) async {
    try {
      _isSyncing = true;
      notifyListeners();

      debugPrint('🔄 Restoring user settings from Supabase...');

      // Log the sync operation
      final syncLogId = await _logSync(
        userId: userId,
        tenantId: tenantId,
        syncType: 'user_settings',
        direction: 'remote_to_local',
      );

      // Get user settings from Supabase
      final response = await _supabase.schema('sms_gateway').rpc(
        'get_user_settings',
        params: {
          'p_user_id': userId,
          'p_tenant_id': tenantId,
        },
      );

      if (response == null || (response as List).isEmpty) {
        debugPrint('⚠️ No user settings found in Supabase, using defaults');
        await _completeSync(syncLogId, 'partial',
            errorMessage: 'No settings found in Supabase');
        return true;
      }

      // Parse response
      final settings = response.first as Map<String, dynamic>;

      // Save to local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'sms_channel', settings['sms_channel'] ?? 'thisPhone');
      await prefs.setBool(
          'api_queue_auto_start', settings['api_queue_auto_start'] ?? false);
      await prefs.setString('theme_mode', settings['theme_mode'] ?? 'light');
      await prefs.setString('language', settings['language'] ?? 'en');
      await prefs.setBool('notification_on_sms_sent',
          settings['notification_on_sms_sent'] ?? true);
      await prefs.setBool('notification_on_sms_failed',
          settings['notification_on_sms_failed'] ?? true);
      await prefs.setBool('notification_on_quota_warning',
          settings['notification_on_quota_warning'] ?? true);

      await _completeSync(syncLogId, 'success');

      _lastSyncTime = DateTime.now();
      _lastSyncStatus = '✅ User settings restored successfully';

      debugPrint('✅ User settings restored: ${settings.length} settings');
      notifyListeners();

      return true;
    } catch (e) {
      _lastSyncStatus = '❌ Error restoring user settings: $e';
      debugPrint(_lastSyncStatus);
      notifyListeners();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // TENANT SETTINGS BACKUP
  // ============================================================================

  /// Backup tenant settings to Supabase
  Future<bool> backupTenantSettings({
    required String tenantId,
  }) async {
    try {
      _isSyncing = true;
      notifyListeners();

      debugPrint('🔄 Backing up tenant settings to Supabase...');

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get local tenant settings
      final prefs = await SharedPreferences.getInstance();
      final tenantSettings = {
        'default_sms_channel':
            prefs.getString('default_sms_channel') ?? 'thisPhone',
        'daily_sms_quota': prefs.getInt('daily_sms_quota') ?? 10000,
        'monthly_sms_quota': prefs.getInt('monthly_sms_quota') ?? 100000,
        'enable_bulk_sms': prefs.getBool('enable_bulk_sms') ?? true,
        'enable_scheduled_sms': prefs.getBool('enable_scheduled_sms') ?? true,
        'enable_sms_groups': prefs.getBool('enable_sms_groups') ?? true,
        'enable_api_access': prefs.getBool('enable_api_access') ?? true,
        'plan_type': prefs.getString('plan_type') ?? 'basic',
      };

      // Log the sync operation
      final syncLogId = await _logSync(
        userId: userId,
        tenantId: tenantId,
        syncType: 'tenant_settings',
        direction: 'local_to_remote',
      );

      // Update tenant settings in Supabase (upsert using onConflict)
      try {
        await _supabase.schema('sms_gateway').from('tenant_settings').upsert(
          {
            'tenant_id': tenantId,
            'default_sms_channel': tenantSettings['default_sms_channel'],
            'daily_sms_quota': tenantSettings['daily_sms_quota'],
            'monthly_sms_quota': tenantSettings['monthly_sms_quota'],
            'enable_bulk_sms': tenantSettings['enable_bulk_sms'],
            'enable_scheduled_sms': tenantSettings['enable_scheduled_sms'],
            'enable_sms_groups': tenantSettings['enable_sms_groups'],
            'enable_api_access': tenantSettings['enable_api_access'],
            'plan_type': tenantSettings['plan_type'],
            'updated_by': userId,
            'updated_at': DateTime.now().toIso8601String(),
          },
        ).eq('tenant_id', tenantId);
      } catch (e) {
        // If upsert fails due to conflict, try update instead
        debugPrint('⚠️ Upsert failed, trying update: $e');
        await _supabase.schema('sms_gateway').from('tenant_settings').update({
          'default_sms_channel': tenantSettings['default_sms_channel'],
          'daily_sms_quota': tenantSettings['daily_sms_quota'],
          'monthly_sms_quota': tenantSettings['monthly_sms_quota'],
          'enable_bulk_sms': tenantSettings['enable_bulk_sms'],
          'enable_scheduled_sms': tenantSettings['enable_scheduled_sms'],
          'enable_sms_groups': tenantSettings['enable_sms_groups'],
          'enable_api_access': tenantSettings['enable_api_access'],
          'plan_type': tenantSettings['plan_type'],
          'updated_by': userId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('tenant_id', tenantId);
      }

      await _completeSync(syncLogId, 'success');

      _lastSyncTime = DateTime.now();
      _lastSyncStatus = '✅ Tenant settings backed up successfully';

      debugPrint(
          '✅ Tenant settings backed up: ${tenantSettings.length} settings');
      notifyListeners();

      return true;
    } catch (e) {
      _lastSyncStatus = '❌ Error backing up tenant settings: $e';
      debugPrint(_lastSyncStatus);
      notifyListeners();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Restore tenant settings from Supabase
  Future<bool> restoreTenantSettings({
    required String tenantId,
  }) async {
    try {
      _isSyncing = true;
      notifyListeners();

      debugPrint('🔄 Restoring tenant settings from Supabase...');

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Log the sync operation
      final syncLogId = await _logSync(
        userId: userId,
        tenantId: tenantId,
        syncType: 'tenant_settings',
        direction: 'remote_to_local',
      );

      // Get tenant settings from Supabase
      final response = await _supabase
          .schema('sms_gateway')
          .from('tenant_settings')
          .select()
          .eq('tenant_id', tenantId)
          .single();

      // Parse response
      final settings = response;

      // Save to local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('default_sms_channel',
          settings['default_sms_channel'] ?? 'thisPhone');
      await prefs.setInt(
          'daily_sms_quota', settings['daily_sms_quota'] ?? 10000);
      await prefs.setInt(
          'monthly_sms_quota', settings['monthly_sms_quota'] ?? 100000);
      await prefs.setBool(
          'enable_bulk_sms', settings['enable_bulk_sms'] ?? true);
      await prefs.setBool(
          'enable_scheduled_sms', settings['enable_scheduled_sms'] ?? true);
      await prefs.setBool(
          'enable_sms_groups', settings['enable_sms_groups'] ?? true);
      await prefs.setBool(
          'enable_api_access', settings['enable_api_access'] ?? true);
      await prefs.setString('plan_type', settings['plan_type'] ?? 'basic');

      await _completeSync(syncLogId, 'success');

      _lastSyncTime = DateTime.now();
      _lastSyncStatus = '✅ Tenant settings restored successfully';

      debugPrint('✅ Tenant settings restored: ${settings.length} settings');
      notifyListeners();

      return true;
    } catch (e) {
      _lastSyncStatus = '❌ Error restoring tenant settings: $e';
      debugPrint(_lastSyncStatus);
      notifyListeners();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // SYNC ALL SETTINGS
  // ============================================================================

  /// Backup all user and tenant settings
  Future<bool> backupAllSettings({
    required String userId,
    required String tenantId,
  }) async {
    try {
      debugPrint('🔄 Starting full settings backup...');

      final userSuccess = await backupUserSettings(
        userId: userId,
        tenantId: tenantId,
      );

      final tenantSuccess = await backupTenantSettings(
        tenantId: tenantId,
      );

      if (userSuccess && tenantSuccess) {
        debugPrint('✅ Full settings backup completed successfully');
        return true;
      } else {
        debugPrint('⚠️ Full settings backup completed with errors');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error during full settings backup: $e');
      return false;
    }
  }

  /// Restore all user and tenant settings
  Future<bool> restoreAllSettings({
    required String userId,
    required String tenantId,
  }) async {
    try {
      debugPrint('🔄 Starting full settings restore...');

      final userSuccess = await restoreUserSettings(
        userId: userId,
        tenantId: tenantId,
      );

      final tenantSuccess = await restoreTenantSettings(
        tenantId: tenantId,
      );

      if (userSuccess && tenantSuccess) {
        debugPrint('✅ Full settings restore completed successfully');
        return true;
      } else {
        debugPrint('⚠️ Full settings restore completed with errors');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error during full settings restore: $e');
      return false;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Log a settings sync operation
  Future<String> _logSync({
    required String userId,
    required String tenantId,
    required String syncType,
    required String direction,
  }) async {
    try {
      final response = await _supabase.schema('sms_gateway').rpc(
        'log_settings_sync',
        params: {
          'p_user_id': userId,
          'p_tenant_id': tenantId,
          'p_sync_type': syncType,
          'p_direction': direction,
          'p_status': 'pending',
        },
      );

      return response as String;
    } catch (e) {
      debugPrint('❌ Error logging sync: $e');
      return '';
    }
  }

  /// Mark a sync operation as completed
  Future<void> _completeSync(
    String logId,
    String status, {
    String? errorMessage,
  }) async {
    try {
      if (logId.isEmpty) return;

      await _supabase.schema('sms_gateway').rpc(
        'complete_settings_sync',
        params: {
          'p_log_id': logId,
          'p_status': status,
          'p_error_message': errorMessage,
        },
      );
    } catch (e) {
      debugPrint('❌ Error completing sync: $e');
    }
  }

  /// Get the last sync status as a formatted string
  String getSyncStatusMessage() {
    if (_lastSyncTime == null) {
      return 'Never synced';
    }

    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  /// Export all local settings as JSON
  Future<Map<String, dynamic>> exportAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allSettings = <String, dynamic>{};

      for (final key in prefs.getKeys()) {
        allSettings[key] = prefs.get(key);
      }

      return {
        'exported_at': DateTime.now().toIso8601String(),
        'settings': allSettings,
      };
    } catch (e) {
      debugPrint('❌ Error exporting settings: $e');
      return {};
    }
  }

  /// Import settings from JSON
  Future<bool> importAllSettings(Map<String, dynamic> settingsJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = settingsJson['settings'] as Map<String, dynamic>;

      for (final entry in settings.entries) {
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
        } else if (value is int) {
          await prefs.setInt(entry.key, value);
        } else if (value is double) {
          await prefs.setDouble(entry.key, value);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else if (value is List<String>) {
          await prefs.setStringList(entry.key, value);
        }
      }

      debugPrint('✅ Settings imported successfully');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error importing settings: $e');
      return false;
    }
  }
}
