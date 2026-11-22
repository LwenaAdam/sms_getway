import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/provider_models.dart';

/// Provider Manager Service - Enables dynamic management of SMS and Payment providers
class ProviderManagerService extends ChangeNotifier {
  static final ProviderManagerService _instance = ProviderManagerService._internal();
  factory ProviderManagerService() => _instance;
  ProviderManagerService._internal();

  static const String _localSmsProvidersKey = 'custom_sms_providers_v1';
  static const String _localPaymentProvidersKey = 'custom_payment_providers_v1';

  List<SmsProviderConfig> _smsProviders = [];
  List<PaymentProviderConfig> _paymentProviders = [];
  bool _isInitialized = false;

  List<SmsProviderConfig> get smsProviders => List.unmodifiable(_smsProviders);
  List<PaymentProviderConfig> get paymentProviders => List.unmodifiable(_paymentProviders);

  SmsProviderConfig? get defaultSmsProvider =>
      _smsProviders.firstWhere((p) => p.isDefault && p.isActive, orElse: () => _smsProviders.firstWhere((p) => p.isActive, orElse: () => _smsProviders.first));

  PaymentProviderConfig? get defaultPaymentProvider =>
      _paymentProviders.firstWhere((p) => p.isDefault && p.isActive, orElse: () => _paymentProviders.firstWhere((p) => p.isActive, orElse: () => _paymentProviders.first));

  /// Initialize and load providers
  Future<void> init() async {
    if (_isInitialized) return;
    await loadProviders();
    _isInitialized = true;
  }

  /// Load providers from cloud or local cache
  Future<void> loadProviders() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load local cache first
      final cachedSms = prefs.getString(_localSmsProvidersKey);
      if (cachedSms != null) {
        final List decoded = jsonDecode(cachedSms);
        _smsProviders = decoded.map((e) => SmsProviderConfig.fromJson(e)).toList();
      }

      final cachedPayments = prefs.getString(_localPaymentProvidersKey);
      if (cachedPayments != null) {
        final List decoded = jsonDecode(cachedPayments);
        _paymentProviders = decoded.map((e) => PaymentProviderConfig.fromJson(e)).toList();
      }

      // If empty, seed default providers (SwalaSMS, PalmPesa, QuickSMS)
      if (_smsProviders.isEmpty) {
        _smsProviders = _getDefaultSmsProviders();
        await _saveLocalSmsProviders();
      }
      if (_paymentProviders.isEmpty) {
        _paymentProviders = _getDefaultPaymentProviders();
        await _saveLocalPaymentProviders();
      }

      // Try syncing from Supabase if online
      await _syncFromSupabase();

      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error loading providers: $e');
    }
  }

  /// Default pre-configured SMS providers
  List<SmsProviderConfig> _getDefaultSmsProviders() {
    return [
      SmsProviderConfig(
        id: 'swala_sms_default',
        name: 'Swala SMS (Tanzania)',
        slug: 'swala_sms',
        endpointUrl: 'https://swalasms.com/api/v1/sms/messages',
        httpMethod: 'POST',
        authType: 'bearer',
        authHeaderKey: 'Authorization',
        apiKey: AppConstants.swalaSmsApiKey,
        senderId: AppConstants.swalaSmsSenderId,
        bodyTemplate: jsonEncode({
          'sender_id': '{{sender_id}}',
          'recipients': ['{{phone}}'],
          'message': '{{message}}',
        }),
        isActive: true,
        isDefault: true,
      ),
      SmsProviderConfig(
        id: 'quicksms_default',
        name: 'QuickSMS',
        slug: 'quicksms',
        endpointUrl: '${AppConstants.quickSmsBaseUrl}/sms/send',
        httpMethod: 'POST',
        authType: 'bearer',
        authHeaderKey: 'Authorization',
        apiKey: AppConstants.quickSmsApiKey,
        senderId: AppConstants.quickSmsSenderId,
        bodyTemplate: jsonEncode({
          'to': '{{phone}}',
          'body': '{{message}}',
          'sender_id': '{{sender_id}}',
        }),
        isActive: true,
        isDefault: false,
      ),
      SmsProviderConfig(
        id: 'beem_africa_template',
        name: 'Beem Africa (SMS)',
        slug: 'beem_africa',
        endpointUrl: 'https://apisms.beem.africa/v1/send',
        httpMethod: 'POST',
        authType: 'basic',
        authHeaderKey: 'Authorization',
        apiKey: '',
        apiSecret: '',
        senderId: 'INFO',
        bodyTemplate: jsonEncode({
          'source_addr': '{{sender_id}}',
          'message': '{{message}}',
          'encoding': 0,
          'recipients': [
            {'recipient_id': 1, 'dest_addr': '{{phone}}'}
          ],
        }),
        isActive: false,
        isDefault: false,
      ),
    ];
  }

  /// Default pre-configured Payment gateways
  List<PaymentProviderConfig> _getDefaultPaymentProviders() {
    return [
      PaymentProviderConfig(
        id: 'palmpesa_default',
        name: 'Palm Pesa Tz',
        slug: 'palmpesa',
        baseUrl: AppConstants.palmPesaBaseUrl,
        endpointUrl: '/api/v2/async/payments',
        merchantId: AppConstants.palmPesaUserRef, // USR-579470B9AB51
        apiToken: AppConstants.palmPesaApiToken,
        currency: 'TZS',
        paymentType: 'mobile_money_ussd',
        supportedChannels: ['Vodacom M-Pesa', 'Tigo Pesa', 'Airtel Money', 'HaloPesa'],
        callbackUrl: 'https://smsgetway.techware.africa/api/payments/palmpesa/callback',
        isActive: true,
        isDefault: true,
      ),
      PaymentProviderConfig(
        id: 'selcom_template',
        name: 'Selcom Pay (Tanzania)',
        slug: 'selcom',
        baseUrl: 'https://api.selcom.net/v1',
        endpointUrl: '/checkout/create-order',
        merchantId: '',
        apiToken: '',
        currency: 'TZS',
        paymentType: 'mobile_money_ussd',
        supportedChannels: ['M-Pesa', 'Tigo Pesa', 'Airtel', 'HaloPesa', 'Cards'],
        isActive: false,
        isDefault: false,
      ),
      PaymentProviderConfig(
        id: 'manual_lipa_namba',
        name: 'Manual Lipa Namba (M-Pesa / Tigo)',
        slug: 'lipa_namba',
        baseUrl: '',
        endpointUrl: '',
        merchantId: 'LIPA_NAMBA_HERE',
        apiToken: '',
        currency: 'TZS',
        paymentType: 'manual_lipa_namba',
        supportedChannels: ['Vodacom Lipa', 'Tigo Lipa', 'Airtel Lipa'],
        isActive: true,
        isDefault: false,
      ),
    ];
  }

  // ==================== SMS PROVIDER CRUD ====================

  Future<void> saveSmsProvider(SmsProviderConfig provider) async {
    final index = _smsProviders.indexWhere((p) => p.id == provider.id);
    if (index >= 0) {
      _smsProviders[index] = provider;
    } else {
      _smsProviders.add(provider);
    }

    if (provider.isDefault) {
      for (int i = 0; i < _smsProviders.length; i++) {
        if (_smsProviders[i].id != provider.id) {
          _smsProviders[i] = _smsProviders[i].copyWith(isDefault: false);
        }
      }
    }

    await _saveLocalSmsProviders();
    await _syncSmsProviderToSupabase(provider);
    notifyListeners();
  }

  Future<void> deleteSmsProvider(String id) async {
    _smsProviders.removeWhere((p) => p.id == id);
    await _saveLocalSmsProviders();
    try {
      await Supabase.instance.client
          .schema('sms_gateway')
          .from('sms_providers')
          .delete()
          .eq('id', id);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setDefaultSmsProvider(String id) async {
    for (int i = 0; i < _smsProviders.length; i++) {
      final isDef = _smsProviders[i].id == id;
      _smsProviders[i] = _smsProviders[i].copyWith(isDefault: isDef, isActive: isDef ? true : _smsProviders[i].isActive);
    }
    await _saveLocalSmsProviders();
    notifyListeners();
  }

  // ==================== PAYMENT PROVIDER CRUD ====================

  Future<void> savePaymentProvider(PaymentProviderConfig provider) async {
    final index = _paymentProviders.indexWhere((p) => p.id == provider.id);
    if (index >= 0) {
      _paymentProviders[index] = provider;
    } else {
      _paymentProviders.add(provider);
    }

    if (provider.isDefault) {
      for (int i = 0; i < _paymentProviders.length; i++) {
        if (_paymentProviders[i].id != provider.id) {
          _paymentProviders[i] = _paymentProviders[i].copyWith(isDefault: false);
        }
      }
    }

    await _saveLocalPaymentProviders();
    await _syncPaymentProviderToSupabase(provider);
    notifyListeners();
  }

  Future<void> deletePaymentProvider(String id) async {
    _paymentProviders.removeWhere((p) => p.id == id);
    await _saveLocalPaymentProviders();
    try {
      await Supabase.instance.client
          .schema('sms_gateway')
          .from('payment_providers')
          .delete()
          .eq('id', id);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setDefaultPaymentProvider(String id) async {
    for (int i = 0; i < _paymentProviders.length; i++) {
      final isDef = _paymentProviders[i].id == id;
      _paymentProviders[i] = _paymentProviders[i].copyWith(isDefault: isDef, isActive: isDef ? true : _paymentProviders[i].isActive);
    }
    await _saveLocalPaymentProviders();
    notifyListeners();
  }

  // ==================== DYNAMIC EXECUTION ====================

  /// Send an SMS dynamically using a given provider or the active default
  Future<({bool success, String message})> sendDynamicSms({
    required String phone,
    required String message,
    SmsProviderConfig? provider,
  }) async {
    final selected = provider ?? defaultSmsProvider;
    if (selected == null) {
      return (success: false, message: 'No SMS provider configured.');
    }

    try {
      debugPrint('📤 [ProviderManager] Sending via SMS provider: ${selected.name}');

      // Normalize phone number (remove + or format to local)
      String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '255${cleanPhone.substring(1)}';
      }

      // Build Headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (selected.authType == 'bearer') {
        headers[selected.authHeaderKey] = 'Bearer ${selected.apiKey}';
      } else if (selected.authType == 'header') {
        headers[selected.authHeaderKey] = selected.apiKey;
      } else if (selected.authType == 'basic') {
        final authStr = '${selected.apiKey}:${selected.apiSecret ?? ""}';
        final basic64 = base64Encode(utf8.encode(authStr));
        headers['Authorization'] = 'Basic $basic64';
      }

      if (selected.customHeaders != null) {
        headers.addAll(selected.customHeaders!);
      }

      // Build Body
      String bodyString = '';
      if (selected.bodyTemplate != null && selected.bodyTemplate!.isNotEmpty) {
        bodyString = selected.bodyTemplate!
            .replaceAll('{{phone}}', cleanPhone)
            .replaceAll('{{message}}', message.replaceAll('"', '\\"').replaceAll('\n', '\\n'))
            .replaceAll('{{sender_id}}', selected.senderId);
      } else {
        bodyString = jsonEncode({
          'sender_id': selected.senderId,
          'recipients': [cleanPhone],
          'message': message,
        });
      }

      final url = Uri.parse(selected.endpointUrl);
      http.Response response;

      if (selected.httpMethod.toUpperCase() == 'GET') {
        response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));
      } else {
        response = await http.post(url, headers: headers, body: bodyString).timeout(const Duration(seconds: 30));
      }

      debugPrint('🔍 [${selected.name}] Response code: ${response.statusCode}');
      debugPrint('📋 [${selected.name}] Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (success: true, message: 'SMS sent successfully via ${selected.name}');
      } else {
        return (success: false, message: 'Failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ [ProviderManager] Send SMS error: $e');
      return (success: false, message: 'Error: $e');
    }
  }

  // ==================== STORAGE HELPERS ====================

  Future<void> _saveLocalSmsProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _smsProviders.map((e) => e.toJson()).toList();
    await prefs.setString(_localSmsProvidersKey, jsonEncode(jsonList));
  }

  Future<void> _saveLocalPaymentProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _paymentProviders.map((e) => e.toJson()).toList();
    await prefs.setString(_localPaymentProvidersKey, jsonEncode(jsonList));
  }

  Future<void> _syncFromSupabase() async {
    try {
      final supabase = Supabase.instance.client;
      final smsData = await supabase.schema('sms_gateway').from('sms_providers').select('*');
      if (smsData.isNotEmpty) {
        _smsProviders = smsData.map((e) => SmsProviderConfig.fromJson(e)).toList();
        await _saveLocalSmsProviders();
      }

      final payData = await supabase.schema('sms_gateway').from('payment_providers').select('*');
      if (payData.isNotEmpty) {
        _paymentProviders = payData.map((e) => PaymentProviderConfig.fromJson(e)).toList();
        await _saveLocalPaymentProviders();
      }
    } catch (_) {}
  }

  Future<void> _syncSmsProviderToSupabase(SmsProviderConfig provider) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.schema('sms_gateway').from('sms_providers').upsert(provider.toJson());
    } catch (_) {}
  }

  Future<void> _syncPaymentProviderToSupabase(PaymentProviderConfig provider) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.schema('sms_gateway').from('payment_providers').upsert(provider.toJson());
    } catch (_) {}
  }
}
