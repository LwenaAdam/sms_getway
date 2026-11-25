import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';

/// Service for handling mobile money payments via Palm Pesa Tanzania
/// (M-Pesa, Tigo Pesa / Mixx by Yas, Airtel Money, HaloPesa)
class PalmPesaService {
  static final PalmPesaService _instance = PalmPesaService._internal();
  factory PalmPesaService() => _instance;
  PalmPesaService._internal();

  static const String _tokenKey = 'palmpesa_api_token';
  static const String _userRefKey = 'palmpesa_user_ref';
  static const String _baseUrlKey = 'palmpesa_base_url';

  /// Get current Palm Pesa API Token
  Future<String> getApiToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null && token.trim().isNotEmpty) return token.trim();
    } catch (_) {}
    return AppConstants.palmPesaApiToken;
  }

  /// Get Public User Reference
  Future<String> getUserRef() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ref = prefs.getString(_userRefKey);
      if (ref != null && ref.trim().isNotEmpty) return ref.trim();
    } catch (_) {}
    return AppConstants.palmPesaUserRef;
  }

  /// Get Base URL
  Future<String> getBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_baseUrlKey);
      if (url != null &&
          url.trim().isNotEmpty &&
          !url.contains('drmlelwa')) {
        return url.trim();
      } else if (url != null && url.contains('drmlelwa')) {
        // Clear obsolete cached drmlelwa domain
        await prefs.remove(_baseUrlKey);
      }
    } catch (_) {}
    return AppConstants.palmPesaBaseUrl;
  }

  /// Save Palm Pesa credentials to SharedPreferences
  Future<void> saveCredentials({
    required String apiToken,
    String? userRef,
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, apiToken.trim());
    if (userRef != null && userRef.trim().isNotEmpty) {
      await prefs.setString(_userRefKey, userRef.trim());
    }
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      await prefs.setString(_baseUrlKey, baseUrl.trim());
    }
  }

  /// Normalize Tanzanian mobile money phone number (255XXXXXXXXX)
  String normalizePhoneNumber(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '255${clean.substring(1)}';
    } else if (clean.startsWith('255')) {
      // already normalized
    } else if (clean.length == 9) {
      clean = '255$clean';
    }
    return clean;
  }

  /// Detect mobile network provider name from phone number
  String detectNetwork(String phone) {
    final clean = normalizePhoneNumber(phone);
    if (clean.length < 5) return 'Mobile Money';
    final prefix = clean.substring(3, 5);
    // Vodacom M-Pesa: 74, 75, 76
    if (['74', '75', '76'].contains(prefix)) return 'Vodacom M-Pesa';
    // Tigo Pesa / Mixx by Yas: 71, 65, 67
    if (['71', '65', '67'].contains(prefix)) return 'Tigo Pesa';
    // Airtel Money: 68, 69, 78
    if (['68', '69', '78'].contains(prefix)) return 'Airtel Money';
    // HaloPesa: 61, 62
    if (['61', '62'].contains(prefix)) return 'HaloPesa';
    return 'Mobile Money (TZ)';
  }

  /// Resolve the effective base URL handling Flutter Web CORS
  String _getEffectiveBaseUrl(String baseUrl) {
    if (kIsWeb) {
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
        // When running on local Chrome, route through the live Netlify proxy with CORS enabled
        return 'https://smsgetway.techware.africa/palmpesa-api';
      }
      // On production Netlify (same origin), route through /palmpesa-api
      return '${Uri.base.origin}/palmpesa-api';
    }
    return baseUrl;
  }

  /// Initiate Money Request / Push USSD to customer's phone
  Future<({bool success, String message, String? transactionId})> requestPayment({
    required String phone,
    required double amount,
    required String planName,
    String? customerName,
    String? customerEmail,
    String? userId,
    String? tenantId,
  }) async {
    try {
      final token = await getApiToken();
      final baseUrl = await getBaseUrl();

      if (token.isEmpty) {
        return (
          success: false,
          message: 'Payment Gateway is not configured. Please contact support.',
          transactionId: null,
        );
      }

      final normalizedPhone = normalizePhoneNumber(phone);
      if (normalizedPhone.length != 12 || !normalizedPhone.startsWith('255')) {
        return (
          success: false,
          message: 'Invalid Tanzanian phone number format. Use format 07XXXXXXXX or 2557XXXXXXXX.',
          transactionId: null,
        );
      }

      final transactionId = 'SGW_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';
      final int amountInTzs = amount.round();

      final payload = {
        'transaction_id': transactionId,
        'amount': amountInTzs,
        'currency': 'TZS',
        'phone': normalizedPhone,
        'name': customerName?.isNotEmpty == true ? customerName! : 'Customer ($normalizedPhone)',
        'email': customerEmail?.isNotEmpty == true ? customerEmail! : 'customer@techware.africa',
        'callback_url': 'https://smsgetway.techware.africa/api/payments/callback',
      };

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final effectiveBase = _getEffectiveBaseUrl(baseUrl);
      debugPrint('💳 [PalmPesa] Initiating payment for $amountInTzs TZS to $normalizedPhone via $effectiveBase...');

      final targetUri = Uri.parse('$effectiveBase/api/v2/async/payments');
      final response = await http
          .post(targetUri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));

      debugPrint('🔍 [PalmPesa] Response status: ${response.statusCode}');
      debugPrint('📋 [PalmPesa] Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String? orderId;
        try {
          final resData = jsonDecode(response.body);
          orderId = resData['data']?['order_id'];
        } catch (_) {}

        // Log transaction to database
        await _logPaymentRecord(
          transactionId: transactionId,
          amount: amount,
          phoneNumber: normalizedPhone,
          planName: planName,
          userId: userId,
          tenantId: tenantId,
          status: 'pending',
          rawResponse: response.body,
        );

        return (
          success: true,
          message: 'USSD prompt sent! Please enter your PIN on your phone to complete payment.',
          transactionId: orderId ?? transactionId,
        );
      } else {
        String errMsg = 'Payment request failed (Status: ${response.statusCode})';
        try {
          final resData = jsonDecode(response.body);
          errMsg = resData['message'] ?? resData['error'] ?? resData['detail'] ?? errMsg;
        } catch (_) {}

        return (
          success: false,
          message: errMsg,
          transactionId: transactionId,
        );
      }
    } catch (e) {
      debugPrint('❌ [PalmPesa] Error initiating payment: $e');
      return (
        success: false,
        message: 'Connection error with payment gateway: $e',
        transactionId: null,
      );
    }
  }

  /// Check payment status by transaction ID or order ID
  Future<String> checkPaymentStatus(String transactionId) async {
    try {
      final token = await getApiToken();
      final baseUrl = await getBaseUrl();
      final effectiveBase = _getEffectiveBaseUrl(baseUrl);

      final url = Uri.parse('$effectiveBase/api/v2/async/payments/$transactionId');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = (data['data']?['status'] ?? data['status'] ?? '').toString().toUpperCase();
        if (status == 'COMPLETED' || status == 'SUCCESS') {
          await _updatePaymentStatus(transactionId, 'completed');
          await creditQuotaForPayment(transactionId);
          return 'completed';
        } else if (status.contains('FAIL') || status.contains('CANCEL') || status.contains('REJECT')) {
          await _updatePaymentStatus(transactionId, 'failed');
          return 'failed';
        }
      }
      return 'pending';
    } catch (e) {
      debugPrint('⚠️ [PalmPesa] Status check failed: $e');
      return 'pending';
    }
  }

  /// Automatically credit SMS quota or activate subscription plan upon successful payment
  Future<void> creditQuotaForPayment(String transactionId) async {
    try {
      final supabase = Supabase.instance.client;
      final payment = await supabase
          .schema('sms_gateway')
          .from('payments')
          .select('tenant_id, plan_name, amount, metadata')
          .eq('transaction_id', transactionId)
          .maybeSingle();

      if (payment == null || payment['tenant_id'] == null) return;

      final metadata = payment['metadata'] is Map
          ? Map<String, dynamic>.from(payment['metadata'])
          : <String, dynamic>{};

      if (metadata['credited'] == true) {
        debugPrint('ℹ️ [PalmPesa] Transaction $transactionId already credited.');
        return;
      }

      final tenantId = payment['tenant_id'] as String;
      final planName = (payment['plan_name'] ?? '').toString().toLowerCase();

      // Read current tenant settings
      final settings = await supabase
          .schema('sms_gateway')
          .from('tenant_settings')
          .select('monthly_sms_quota, daily_sms_quota, plan_type')
          .eq('tenant_id', tenantId)
          .maybeSingle();

      int currentMonthlyQuota = settings?['monthly_sms_quota'] as int? ?? 1000;
      int currentDailyQuota = settings?['daily_sms_quota'] as int? ?? 100;
      String newPlanType = settings?['plan_type'] as String? ?? 'basic';

      if (planName.contains('1,000') ||
          planName.contains('top-up') ||
          planName.contains('credit')) {
        currentMonthlyQuota += 1000;
        currentDailyQuota = currentDailyQuota < 500 ? 500 : currentDailyQuota;
      } else if (planName.contains('starter')) {
        newPlanType = 'starter';
        currentMonthlyQuota = currentMonthlyQuota < 25000 ? 25000 : currentMonthlyQuota + 25000;
        currentDailyQuota = currentDailyQuota < 1000 ? 1000 : currentDailyQuota;
      } else if (planName.contains('business') || planName.contains('pro')) {
        newPlanType = 'pro';
        currentMonthlyQuota = currentMonthlyQuota < 100000 ? 100000 : currentMonthlyQuota + 100000;
        currentDailyQuota = currentDailyQuota < 5000 ? 5000 : currentDailyQuota;
      } else {
        currentMonthlyQuota += 1000;
      }

      if (settings != null) {
        await supabase.schema('sms_gateway').from('tenant_settings').update({
          'monthly_sms_quota': currentMonthlyQuota,
          'daily_sms_quota': currentDailyQuota,
          'plan_type': newPlanType,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('tenant_id', tenantId);
      } else {
        try {
          await supabase.schema('sms_gateway').from('tenant_settings').insert({
            'tenant_id': tenantId,
            'default_sms_channel': 'thisPhone',
            'daily_sms_quota': currentDailyQuota,
            'monthly_sms_quota': currentMonthlyQuota,
            'plan_type': newPlanType,
            'enable_bulk_sms': true,
          });
        } catch (e) {
          debugPrint('⚠️ [PalmPesa] Fallback insert tenant_settings: $e');
          await supabase.schema('sms_gateway').from('tenant_settings').upsert({
            'tenant_id': tenantId,
            'monthly_sms_quota': currentMonthlyQuota,
            'daily_sms_quota': currentDailyQuota,
            'plan_type': newPlanType,
          }, onConflict: 'tenant_id');
        }
      }

      // Mark payment as credited in metadata
      metadata['credited'] = true;
      metadata['credited_at'] = DateTime.now().toIso8601String();
      metadata['new_monthly_quota'] = currentMonthlyQuota;
      metadata['new_plan_type'] = newPlanType;

      await supabase
          .schema('sms_gateway')
          .from('payments')
          .update({'metadata': metadata})
          .eq('transaction_id', transactionId);

      debugPrint('🎉 [PalmPesa] Quota credited successfully! New Monthly Quota: $currentMonthlyQuota ($newPlanType)');
    } catch (e) {
      debugPrint('⚠️ [PalmPesa] Error crediting quota: $e');
    }
  }

  /// Check all pending payments for a tenant/user and credit completed ones
  Future<int> syncPendingPayments({String? tenantId, String? userId}) async {
    try {
      final supabase = Supabase.instance.client;
      var query = supabase
          .schema('sms_gateway')
          .from('payments')
          .select()
          .eq('status', 'pending');

      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      } else if (userId != null && userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      }

      final pendingList = await query.limit(10);
      int resolvedCount = 0;

      for (final tx in pendingList) {
        final txId = tx['transaction_id'] as String?;
        if (txId == null || txId.isEmpty) continue;

        final status = await checkPaymentStatus(txId);
        if (status == 'completed') {
          resolvedCount++;
        }
      }
      return resolvedCount;
    } catch (e) {
      debugPrint('⚠️ [PalmPesa] Error syncing pending payments: $e');
      return 0;
    }
  }

  /// Store payment record in Supabase
  Future<void> _logPaymentRecord({
    required String transactionId,
    required double amount,
    required String phoneNumber,
    required String planName,
    required String? userId,
    required String? tenantId,
    required String status,
    required String rawResponse,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.schema('sms_gateway').from('payments').insert({
        'id': const Uuid().v4(),
        'transaction_id': transactionId,
        'amount': amount,
        'currency': 'TZS',
        'phone_number': phoneNumber,
        'plan_name': planName,
        'user_id': userId,
        'tenant_id': tenantId,
        'status': status,
        'provider': 'palmpesa',
        'metadata': {'response': rawResponse},
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('📝 [PalmPesa] Payment recorded in database');
    } catch (e) {
      debugPrint('⚠️ [PalmPesa] Could not log payment to database: $e');
    }
  }

  /// Update payment record status in Supabase
  Future<void> _updatePaymentStatus(String transactionId, String status) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .schema('sms_gateway')
          .from('payments')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('transaction_id', transactionId);
    } catch (_) {}
  }
}
