/// SMS Service - Handles SMS sending via QuickSMS API or Native Android SMS
/// Provides automatic background SMS sending without user intervention

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../sms/sms_log_model.dart';
import '../api/native_sms_service.dart';

class SmsService {
  static const String _channelKey = 'sms_channel';

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
      } else {
        success = await sendViaNativeAndroid(
          phoneNumber: phoneNumber,
          message: message,
          userId: userId,
          tenantId: tenantId,
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
