/// SMS Service - Handles SMS sending via QuickSMS API or Native Android SMS
/// Provides automatic background SMS sending without user intervention
library;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../sms/sms_log_model.dart';
import '../api/native_sms_service.dart';
import '../models/provider_models.dart';
import 'provider_manager_service.dart';

class SmsService {
  static const String _channelKey = 'sms_channel';

  /// Get Swala SMS API key from SharedPreferences with fallback to AppConstants
  static Future<String> getSwalaApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString('swala_sms_api_key');
      if (key != null && key.trim().isNotEmpty) return key.trim();
    } catch (_) {}
    return AppConstants.swalaSmsApiKey;
  }

  /// Get Swala SMS Sender ID from SharedPreferences with fallback to AppConstants
  static Future<String> getSwalaSenderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sender = prefs.getString('swala_sms_sender_id');
      if (sender != null && sender.trim().isNotEmpty) return sender.trim();
    } catch (_) {}
    return AppConstants.swalaSmsSenderId;
  }

  /// Save Swala SMS credentials to SharedPreferences
  static Future<void> saveSwalaCredentials({
    required String apiKey,
    required String senderId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('swala_sms_api_key', apiKey.trim());
    await prefs.setString('swala_sms_sender_id', senderId.trim());
  }

  /// Get saved SMS channel preference
  static Future<String> getSelectedChannel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_channelKey) ?? 'thisPhone';
    } catch (e) {
      debugPrint('❌ Error loading channel: $e');
      return 'thisPhone';
    }
  }

  /// Send SMS using Swala SMS API (https://swalasms.com)
  static Future<bool> sendViaSwalaSms({
    required String phoneNumber,
    required String message,
    required String userId,
    required String? tenantId,
  }) async {
    try {
      debugPrint('📱 Sending SMS via SwalaSMS to: $phoneNumber');

      final apiKey = await getSwalaApiKey();
      final senderId = await getSwalaSenderId();

      if (apiKey.isEmpty) {
        throw Exception(
          'SwalaSMS API Key is not configured. Please add it in Settings → SMS Channel.',
        );
      }

      final url = Uri.parse('${AppConstants.swalaSmsBaseUrl}/sms/messages');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

      // Normalize phone number (Swala SMS expects e.g. 255XXXXXXXXX)
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '255${cleanPhone.substring(1)}';
      }

      final body = jsonEncode({
        'sender_id': senderId.isNotEmpty ? senderId : 'SMS_GATEWAY',
        'recipients': [cleanPhone],
        'message': message,
      });

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('SwalaSMS request timeout');
        },
      );

      debugPrint('🔍 SwalaSMS Response: ${response.statusCode}');
      debugPrint('📋 Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _logSmsToDatabase(
          phoneNumber: cleanPhone,
          message: message,
          userId: userId,
          tenantId: tenantId,
          status: AppConstants.smsSent,
          errorMessage: null,
        );

        debugPrint('✅ SMS sent successfully via SwalaSMS');
        return true;
      } else {
        String errMsg = 'Status ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errMsg = errorData['message'] ?? errorData['error'] ?? response.body;
        } catch (_) {
          errMsg = response.body;
        }
        throw Exception('SwalaSMS Error: $errMsg');
      }
    } catch (e) {
      debugPrint('❌ SwalaSMS Error: $e');

      await _logSmsToDatabase(
        phoneNumber: phoneNumber,
        message: message,
        userId: userId,
        tenantId: tenantId,
        status: AppConstants.smsFailed,
        errorMessage: e.toString(),
      );

      return false;
    }
  }

  /// Send SMS using QuickSMS API
  static Future<bool> sendViaQuickSms({
    required String phoneNumber,
    required String message,
    required String userId,
    required String? tenantId,
  }) async {
    try {
      debugPrint('📱 Sending SMS via QuickSMS to: $phoneNumber');

      // Prepare request
      final url = Uri.parse('${AppConstants.quickSmsBaseUrl}/sms/send');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConstants.quickSmsApiKey}',
      };

      final body = jsonEncode({
        'to': phoneNumber,
        'body': message,
        'sender_id': AppConstants.quickSmsSenderId,
      });

      // Send request
      final response =
          await http.post(url, headers: headers, body: body).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('QuickSMS request timeout');
        },
      );

      debugPrint('🔍 QuickSMS Response: ${response.statusCode}');
      debugPrint('📋 Response Body: ${response.body}');

      // Check response
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Log SMS to database
        await _logSmsToDatabase(
          phoneNumber: phoneNumber,
          message: message,
          userId: userId,
          tenantId: tenantId,
          status: AppConstants.smsSent,
          errorMessage: null,
        );

        debugPrint('✅ SMS sent successfully via QuickSMS');
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
            'QuickSMS Error: ${error['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint('❌ QuickSMS Error: $e');

      // Log failed SMS to database
      await _logSmsToDatabase(
        phoneNumber: phoneNumber,
        message: message,
        userId: userId,
        tenantId: tenantId,
        status: AppConstants.smsFailed,
        errorMessage: e.toString(),
      );

      return false;
    }
  }

  /// Send SMS using native Android SMS (requires device SIM)
  /// This uses platform channels to invoke Android native SMS functionality
  static Future<bool> sendViaNativeAndroid({
    required String phoneNumber,
    required String message,
    required String userId,
    required String? tenantId,
  }) async {
    try {
      debugPrint('📱 Sending SMS via Native Android to: $phoneNumber');

      // Use the NativeSmsService to send SMS via Android platform channel
      final success = await NativeSmsService.sendSms(
        phoneNumber: phoneNumber,
        message: message,
      );

      if (success) {
        // Log successful SMS to database
        await _logSmsToDatabase(
          phoneNumber: phoneNumber,
          message: message,
          userId: userId,
          tenantId: tenantId,
          status: AppConstants.smsSent,
          errorMessage: null,
        );

        debugPrint('✅ SMS sent successfully via Native Android');
        return true;
      } else {
        // Log failed SMS to database
        await _logSmsToDatabase(
          phoneNumber: phoneNumber,
          message: message,
          userId: userId,
          tenantId: tenantId,
          status: AppConstants.smsFailed,
          errorMessage: 'Native Android SMS sending failed',
        );

        debugPrint('❌ Failed to send SMS via Native Android');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Native Android SMS Error: $e');

      // Log error SMS to database
      await _logSmsToDatabase(
        phoneNumber: phoneNumber,
        message: message,
        userId: userId,
        tenantId: tenantId,
        status: AppConstants.smsFailed,
        errorMessage: e.toString(),
      );

      return false;
    }
  }

  /// Send SMS using dynamic provider configured by admin in ProviderManagerService
  static Future<bool> sendViaDynamicProvider({
    required String phoneNumber,
    required String message,
    required String userId,
    required String? tenantId,
    String? providerId,
  }) async {
    try {
      final manager = ProviderManagerService();
      await manager.init();

      SmsProviderConfig? targetProvider;
      if (providerId != null && providerId.isNotEmpty) {
        try {
          targetProvider = manager.smsProviders.firstWhere((p) => p.id == providerId || p.slug == providerId);
        } catch (_) {}
      }
      targetProvider ??= manager.defaultSmsProvider;

      if (targetProvider == null) {
        throw Exception('No active SMS provider configured. Please configure in Settings → Gateway & Provider Manager.');
      }

      final result = await manager.sendDynamicSms(
        phone: phoneNumber,
        message: message,
        provider: targetProvider,
      );

      if (result.success) {
        await _logSmsToDatabase(
          phoneNumber: phoneNumber,
          message: message,
          userId: userId,
          tenantId: tenantId,
          status: AppConstants.smsSent,
          errorMessage: null,
        );
        return true;
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      debugPrint('❌ Dynamic Provider Error: $e');
      await _logSmsToDatabase(
        phoneNumber: phoneNumber,
        message: message,
        userId: userId,
        tenantId: tenantId,
        status: AppConstants.smsFailed,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Send bulk SMS to multiple recipients
  static Future<Map<String, dynamic>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    required String userId,
    required String? tenantId,
  }) async {
    debugPrint(
        '📤 Starting bulk SMS send to ${phoneNumbers.length} recipients');

    int successCount = 0;
    int failureCount = 0;
    final List<String> failedNumbers = [];

    // Get selected channel
    final channel = await getSelectedChannel();
    debugPrint('🔧 Using channel: $channel');

    // Send SMS to each recipient
    for (final phoneNumber in phoneNumbers) {
      bool success = false;

      if (channel == 'quickSMS') {
        success = await sendViaQuickSms(
          phoneNumber: phoneNumber,
          message: message,
          userId: userId,
          tenantId: tenantId,
        );
      } else if (channel == 'swalaSMS') {
        success = await sendViaSwalaSms(
          phoneNumber: phoneNumber,
          message: message,
          userId: userId,
          tenantId: tenantId,
        );
      } else if (channel == 'thisPhone') {
        success = await sendViaNativeAndroid(
          phoneNumber: phoneNumber,
          message: message,
          userId: userId,
          tenantId: tenantId,
        );
      } else {
        // Any custom provider ID (e.g. 'provider:xyz' or 'slug')
        final provId = channel.startsWith('provider:')
            ? channel.replaceFirst('provider:', '')
            : channel;
        success = await sendViaDynamicProvider(
          phoneNumber: phoneNumber,
          message: message,
          userId: userId,
          tenantId: tenantId,
          providerId: provId,
        );
      }

      if (success) {
        successCount++;
      } else {
        failureCount++;
        failedNumbers.add(phoneNumber);
      }

      // Add small delay between sends to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }

    debugPrint(
        '✅ Bulk SMS Complete - Success: $successCount, Failed: $failureCount');

    return {
      'total': phoneNumbers.length,
      'success': successCount,
      'failed': failureCount,
      'failedNumbers': failedNumbers,
    };
  }

  /// Log SMS to database
  static Future<void> _logSmsToDatabase({
    required String phoneNumber,
    required String message,
    required String userId,
    required String? tenantId,
    required String status,
    required String? errorMessage,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final smsLog = SmsLog(
        id: const Uuid().v4(),
        userId: userId,
        tenantId: tenantId,
        contactId: null,
        phoneNumber: phoneNumber,
        message: message,
        status: status,
        sentAt: DateTime.now(),
        errorMessage: errorMessage,
        createdAt: DateTime.now(),
      );

      await supabase
          .schema('sms_gateway')
          .from('sms_logs')
          .insert(smsLog.toJson());

      debugPrint('📝 SMS logged to database');
    } catch (e) {
      debugPrint('❌ Error logging SMS: $e');
    }
  }
}
