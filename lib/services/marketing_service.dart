import 'package:flutter/services.dart';

/// Marketing Automation Service
///
/// Flutter service that communicates with Android marketing workers
/// via MethodChannel.
class MarketingService {
  static const MethodChannel _channel =
      MethodChannel('com.lwenatech.sms_gateway/marketing');

  /// Enable marketing automation
  ///
  /// [tenantId] - Tenant UUID
  /// [userId] - User UUID (from auth.users)
  /// [dailyLimit] - Max SMS per day (default: 100)
  /// [accessToken] - User's Supabase JWT token for RLS
  Future<bool> enableMarketing(String tenantId, String userId,
      {int dailyLimit = 100, String? accessToken}) async {
    try {
      final result = await _channel.invokeMethod('enableMarketing', {
        'tenant_id': tenantId,
        'user_id': userId,
        'daily_limit': dailyLimit,
        'access_token': accessToken,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Disable marketing automation
  Future<bool> disableMarketing() async {
    try {
      final result = await _channel.invokeMethod('disableMarketing');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Check if marketing is enabled
  Future<bool> isMarketingEnabled() async {
    try {
      final result = await _channel.invokeMethod('isMarketingEnabled');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Get marketing settings
  Future<Map<String, dynamic>?> getSettings() async {
    try {
      final result = await _channel.invokeMethod('getMarketingSettings');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return null;
    }
  }

  /// Update daily limit
  Future<bool> setDailyLimit(int limit) async {
    try {
      final result = await _channel.invokeMethod('setDailyLimit', {
        'daily_limit': limit,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Reset daily counter
  Future<bool> resetDailyCounter() async {
    try {
      final result = await _channel.invokeMethod('resetDailyCounter');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Get campaign statistics
  Future<Map<String, int>?> getCampaignStats(String campaignId) async {
    try {
      final result = await _channel.invokeMethod('getCampaignStats', {
        'campaign_id': campaignId,
      });
      return Map<String, int>.from(result);
    } catch (e) {
      return null;
    }
  }

  /// Check if phone can receive marketing SMS
  Future<bool> canSendToPhone(String tenantId, String phoneNumber) async {
    try {
      final result = await _channel.invokeMethod('canSendToPhone', {
        'tenant_id': tenantId,
        'phone_number': phoneNumber,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Get reason why phone cannot receive SMS
  Future<String?> getBlockReason(String tenantId, String phoneNumber) async {
    try {
      final result = await _channel.invokeMethod('getBlockReason', {
        'tenant_id': tenantId,
        'phone_number': phoneNumber,
      });
      return result?.toString();
    } catch (e) {
      return null;
    }
  }

  /// Get remaining SMS quota for phone
  Future<int> getRemainingQuota(String tenantId, String phoneNumber) async {
    try {
      final result = await _channel.invokeMethod('getRemainingQuota', {
        'tenant_id': tenantId,
        'phone_number': phoneNumber,
      });
      return result ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Add phone to opt-out list
  Future<bool> addOptOut(String tenantId, String phoneNumber) async {
    try {
      final result = await _channel.invokeMethod('addOptOut', {
        'tenant_id': tenantId,
        'phone_number': phoneNumber,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Remove phone from opt-out list
  Future<bool> removeOptOut(String tenantId, String phoneNumber) async {
    try {
      final result = await _channel.invokeMethod('removeOptOut', {
        'tenant_id': tenantId,
        'phone_number': phoneNumber,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Force immediate campaign check
  Future<bool> forceCheckNow() async {
    try {
      final result = await _channel.invokeMethod('forceCheckNow');
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
