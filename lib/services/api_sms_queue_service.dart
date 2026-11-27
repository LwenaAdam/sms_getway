/// API SMS Queue Service - Processes SMS requests from external API
/// This service polls Supabase for pending SMS requests and sends them
/// using the device's SMS capability.
library;

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/tenant_service.dart';
import 'sms_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Model for SMS Request from API queue
class SmsRequest {
  final String id;
  final String tenantId;
  final String apiKeyId;
  final String phoneNumber;
  final String message;
  final String status;
  final int priority;
  final DateTime? scheduledAt;
  final DateTime? processedAt;
  final String? errorMessage;
  final String? externalId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  SmsRequest({
    required this.id,
    required this.tenantId,
    required this.apiKeyId,
    required this.phoneNumber,
    required this.message,
    required this.status,
    required this.priority,
    this.scheduledAt,
    this.processedAt,
    this.errorMessage,
    this.externalId,
    this.metadata,
    required this.createdAt,
  });

  factory SmsRequest.fromJson(Map<String, dynamic> json) {
    // Polymorphic phone resolution
    final phone = json['phone_number'] ??
        json['phone'] ??
        json['to'] ??
        json['msisdn'] ??
        json['dest_addr'] ??
        '';

    // Polymorphic message resolution
    final msg = json['message'] ??
        json['text'] ??
        json['body'] ??
        json['sms'] ??
        json['content'] ??
        '';

    return SmsRequest(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      apiKeyId: json['api_key_id'] as String? ?? '',
      phoneNumber: phone.toString(),
      message: msg.toString(),
      status: json['status'] as String? ?? 'pending',
      priority: json['priority'] as int? ?? 0,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
      externalId: json['external_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Model for API Key
class ApiKey {
  final String id;
  final String userId;
  final String tenantId;
  final String name;
  final DateTime? lastUsed;
  final bool active;
  final DateTime createdAt;

  ApiKey({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.name,
    this.lastUsed,
    required this.active,
    required this.createdAt,
  });

  factory ApiKey.fromJson(Map<String, dynamic> json) {
    return ApiKey(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      lastUsed: json['last_used'] != null
          ? DateTime.parse(json['last_used'] as String)
          : null,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Service for processing API SMS queue
class ApiSmsQueueService extends ChangeNotifier {
  // Singleton pattern
  static final ApiSmsQueueService _instance = ApiSmsQueueService._internal();
  factory ApiSmsQueueService() => _instance;
  ApiSmsQueueService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  Timer? _pollTimer;
  bool _isProcessing = false;
  bool _isEnabled = false;
  int _pendingCount = 0;
  int _processedToday = 0;
  DateTime? _lastProcessedAt;

  // Getters
  bool get isProcessing => _isProcessing;
  bool get isEnabled => _isEnabled;
  int get pendingCount => _pendingCount;
  int get processedToday => _processedToday;
  DateTime? get lastProcessedAt => _lastProcessedAt;

  // ============================================================================
  // SERVICE LIFECYCLE
  // ============================================================================

  /// Start the queue processing service
  Future<bool> start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('⚠️ API SMS Queue Service is Android-only');
      return false;
    }

    if (_isEnabled) {
      debugPrint('⚠️ API SMS Queue Service already running');
      return true;
    }

    // Proactively verify SMS permission before starting background worker
    final status = await Permission.sms.status;
    if (!status.isGranted) {
      final requested = await Permission.sms.request();
      if (!requested.isGranted) {
        debugPrint('❌ Cannot start API SMS Queue Service: SMS permission denied by user');
        return false;
      }
    }

    debugPrint('🚀 Starting API SMS Queue Service...');
    debugPrint('📊 Current tenant: ${TenantService().tenantId}');
    _isEnabled = true;

    // Initial fetch of pending count
    await _refreshPendingCount();

    // Start polling every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      debugPrint('⏰ Timer fired - checking queue...');
      _processQueue();
    });

    // Process immediately
    debugPrint('🔄 Processing queue immediately...');
    await _processQueue();

    notifyListeners();
    debugPrint('✅ API SMS Queue Service started - polling every 30s');
    return true;
  }

  /// Stop the queue processing service
  void stop() {
    debugPrint('🛑 Stopping API SMS Queue Service...');
    _pollTimer?.cancel();
    _pollTimer = null;
    _isEnabled = false;
    notifyListeners();
    debugPrint('✅ API SMS Queue Service stopped');
  }

  /// Dispose resources
  @override
  void dispose() {
    stop();
    super.dispose();
  }

  // ============================================================================
  // QUEUE PROCESSING
  // ============================================================================

  /// Process pending SMS requests in the queue
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    if (!_isEnabled) return;

    final tenantId = TenantService().tenantId;
    debugPrint('🔍 Checking queue for tenant: $tenantId');

    _isProcessing = true;
    notifyListeners();

    try {
      // Fetch pending requests for current tenant (prioritized, scheduled ones ready)
      var query = _supabase
          .schema('sms_gateway')
          .from('sms_requests')
          .select()
          .eq('status', 'pending');

      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query
          .or('scheduled_at.is.null,scheduled_at.lte.${DateTime.now().toIso8601String()}')
          .order('priority', ascending: false)
          .order('created_at', ascending: true)
          .limit(10);

      final requests = (response as List)
          .map((json) => SmsRequest.fromJson(json as Map<String, dynamic>))
          .toList();

      if (requests.isEmpty) {
        debugPrint('📭 No pending SMS requests in queue (tenant: $tenantId)');
        _isProcessing = false;
        await _refreshPendingCount();
        notifyListeners();
        return;
      }

      debugPrint(
          '📬 Processing ${requests.length} SMS requests (found ${requests.map((r) => r.tenantId).toSet().length} unique tenants)...');
      debugPrint(
          '🔍 Request tenant IDs: ${requests.map((r) => r.tenantId).toSet()}');

      for (final request in requests) {
        await _processSingleRequest(request);
      }

      await _refreshPendingCount();
    } catch (e) {
      debugPrint('❌ Error processing queue: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Process a single SMS request
  Future<void> _processSingleRequest(SmsRequest request) async {
    try {
      // Mark as processing
      await _updateRequestStatus(request.id, 'processing');

      // Get current user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        await _updateRequestStatus(request.id, 'failed',
            errorMessage: 'User not authenticated');
        return;
      }

      final activeTenantId = TenantService().tenantId;
      final effectiveTenantId = (request.tenantId.isNotEmpty && request.tenantId != 'null')
          ? request.tenantId
          : (activeTenantId ?? '');

      // Check user's SMS channel preference
      final selectedChannel = await SmsService.getSelectedChannel();
      debugPrint('📱 Using SMS channel: $selectedChannel for tenant $effectiveTenantId');

      // =========================================================================
      // STRICT QUOTA & PLAN LIMIT VERIFICATION BEFORE SENDING
      // =========================================================================
      if (selectedChannel == 'thisPhone') {
        try {
          final settingsRes = await _supabase
              .schema('sms_gateway')
              .from('tenant_settings')
              .select('plan_type')
              .eq('tenant_id', effectiveTenantId)
              .maybeSingle();

          final planType = (settingsRes?['plan_type'] as String?) ?? 'basic';

          if (planType == 'basic') {
            // Check total SIM SMS sent across sms_logs and sms_requests
            final logsCountRes = await _supabase
                .schema('sms_gateway')
                .from('sms_logs')
                .select('id')
                .eq('tenant_id', effectiveTenantId)
                .eq('status', 'sent')
                .eq('channel', 'thisPhone')
                .count(CountOption.exact);

            final reqsCountRes = await _supabase
                .schema('sms_gateway')
                .from('sms_requests')
                .select('id')
                .eq('tenant_id', effectiveTenantId)
                .eq('status', 'sent')
                .count(CountOption.exact);

            final totalPhoneSent = (logsCountRes.count > reqsCountRes.count)
                ? logsCountRes.count
                : reqsCountRes.count;

            const int freePhoneLimit = 100;
            if (totalPhoneSent >= freePhoneLimit) {
              debugPrint('🛑 Queue Halted: Free phone SIM limit ($freePhoneLimit) reached for tenant $effectiveTenantId');
              await _updateRequestStatus(
                request.id,
                'failed',
                errorMessage:
                    'Phone SIM free limit ($freePhoneLimit SMS) reached on Basic plan. Upgrade to Starter Gateway (25,000 TZS/mo) to unlock unlimited sending.',
              );
              stop(); // Stop automated queue processing to prevent infinite retry loops
              notifyListeners();
              return;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error verifying SIM limit in queue: $e');
        }
      } else {
        // Cloud Gateway (Sender ID) - Check available credit balance
        try {
          final settingsRes = await _supabase
              .schema('sms_gateway')
              .from('tenant_settings')
              .select('monthly_sms_quota')
              .eq('tenant_id', effectiveTenantId)
              .maybeSingle();

          final totalCredits =
              (settingsRes?['monthly_sms_quota'] as int?) ?? 0;

          final countRes = await _supabase
              .schema('sms_gateway')
              .from('sms_logs')
              .select('id')
              .eq('tenant_id', effectiveTenantId)
              .eq('status', 'sent')
              .neq('channel', 'thisPhone')
              .count(CountOption.exact);

          final int availableCredits =
              (totalCredits - countRes.count).clamp(0, 999999999);

          if (availableCredits <= 0) {
            debugPrint('🛑 Queue Halted: 0 Cloud SMS credits available for tenant $effectiveTenantId');
            await _updateRequestStatus(
              request.id,
              'failed',
              errorMessage:
                  'Insufficient Cloud SMS credits (Balance: 0). Top up credits freely (from just 15 SMS = 225 TZS) to send.',
            );
            stop(); // Stop automated queue processing
            notifyListeners();
            return;
          }
        } catch (e) {
          debugPrint('⚠️ Error verifying cloud credits in queue: $e');
        }
      }

      // Send the SMS using the selected channel
      final success = selectedChannel == 'quickSMS'
          ? await SmsService.sendViaQuickSms(
              phoneNumber: request.phoneNumber,
              message: request.message,
              userId: userId,
              tenantId: effectiveTenantId,
            )
          : selectedChannel == 'swalaSMS'
              ? await SmsService.sendViaSwalaSms(
                  phoneNumber: request.phoneNumber,
                  message: request.message,
                  userId: userId,
                  tenantId: effectiveTenantId,
                )
          : selectedChannel == 'thisPhone'
              ? await SmsService.sendViaNativeAndroid(
                  phoneNumber: request.phoneNumber,
                  message: request.message,
                  userId: userId,
                  tenantId: effectiveTenantId,
                )
              : await SmsService.sendViaDynamicProvider(
                  phoneNumber: request.phoneNumber,
                  message: request.message,
                  userId: userId,
                  tenantId: effectiveTenantId,
                  providerId: selectedChannel.startsWith('provider:')
                      ? selectedChannel.replaceFirst('provider:', '')
                      : selectedChannel,
                );

      if (success) {
        await _updateRequestStatus(request.id, 'sent');
        _processedToday++;
        _lastProcessedAt = DateTime.now();
        debugPrint('✅ SMS sent to ${request.phoneNumber}');
      } else {
        // Mark as failed so it appears in logs but user can see what went wrong
        await _updateRequestStatus(request.id, 'failed',
            errorMessage:
                'Failed to send SMS - check permissions and retry manually');
        debugPrint('❌ Failed to send SMS to ${request.phoneNumber}');
      }
    } catch (e) {
      debugPrint('❌ Error processing request ${request.id}: $e');
      await _updateRequestStatus(request.id, 'failed',
          errorMessage: e.toString());
    }
  }

  /// Update the status of an SMS request
  Future<void> _updateRequestStatus(String requestId, String status,
      {String? errorMessage}) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == 'sent' || status == 'failed') {
        updates['processed_at'] = DateTime.now().toIso8601String();
      }

      if (errorMessage != null) {
        updates['error_message'] = errorMessage;
      }

      await _supabase
          .schema('sms_gateway')
          .from('sms_requests')
          .update(updates)
          .eq('id', requestId);
    } catch (e) {
      debugPrint('❌ Error updating request status: $e');
    }
  }

  /// Refresh the count of pending requests
  Future<void> _refreshPendingCount() async {
    try {
      final tenantId = TenantService().tenantId;

      // Count all pending requests (not filtered by tenant)
      final response = await _supabase
          .schema('sms_gateway')
          .from('sms_requests')
          .select('id')
          .eq('status', 'pending');

      _pendingCount = (response as List).length;
      debugPrint('📊 Pending SMS requests: $_pendingCount (tenant: $tenantId)');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error refreshing pending count: $e');
    }
  }

  /// Manually trigger queue processing
  Future<void> processNow() async {
    await _processQueue();
  }

  // ============================================================================
  // QUEUE MANAGEMENT
  // ============================================================================

  /// Get all SMS requests with optional filters
  Future<List<SmsRequest>> getRequests({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final tenantId = TenantService().tenantId;
      if (tenantId == null) return [];

      var query = _supabase
          .schema('sms_gateway')
          .from('sms_requests')
          .select()
          .eq('tenant_id', tenantId);

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => SmsRequest.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching requests: $e');
      return [];
    }
  }

  /// Cancel a pending SMS request
  Future<bool> cancelRequest(String requestId) async {
    try {
      await _supabase
          .schema('sms_gateway')
          .from('sms_requests')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('status', 'pending');

      await _refreshPendingCount();
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling request: $e');
      return false;
    }
  }

  /// Retry a failed SMS request
  Future<bool> retryRequest(String requestId) async {
    try {
      await _supabase
          .schema('sms_gateway')
          .from('sms_requests')
          .update({
            'status': 'pending',
            'error_message': null,
            'processed_at': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('status', 'failed');

      await _refreshPendingCount();
      return true;
    } catch (e) {
      debugPrint('❌ Error retrying request: $e');
      return false;
    }
  }

  /// Get queue statistics
  Future<Map<String, int>> getQueueStats() async {
    try {
      final tenantId = TenantService().tenantId;
      if (tenantId == null) {
        return {'pending': 0, 'processing': 0, 'sent': 0, 'failed': 0};
      }

      final response = await _supabase
          .schema('sms_gateway')
          .from('sms_requests')
          .select('status')
          .eq('tenant_id', tenantId);

      final statuses = (response as List).map((e) => e['status'] as String);

      return {
        'pending': statuses.where((s) => s == 'pending').length,
        'processing': statuses.where((s) => s == 'processing').length,
        'sent': statuses.where((s) => s == 'sent').length,
        'failed': statuses.where((s) => s == 'failed').length,
        'cancelled': statuses.where((s) => s == 'cancelled').length,
      };
    } catch (e) {
      debugPrint('❌ Error fetching queue stats: $e');
      return {'pending': 0, 'processing': 0, 'sent': 0, 'failed': 0};
    }
  }

  // ============================================================================
  // API KEY MANAGEMENT
  // ============================================================================

  /// Get all API keys for current tenant
  Future<List<ApiKey>> getApiKeys() async {
    try {
      final tenantId = TenantService().tenantId;
      if (tenantId == null) return [];

      final response = await _supabase
          .schema('sms_gateway')
          .from('api_keys')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ApiKey.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching API keys: $e');
      return [];
    }
  }

  /// Generate a new API key
  /// Returns the raw key (only shown once) and the created ApiKey object
  Future<({String rawKey, ApiKey apiKey})?> createApiKey(String name) async {
    try {
      final tenantId = TenantService().tenantId;
      final userId = _supabase.auth.currentUser?.id;

      if (tenantId == null || userId == null) {
        debugPrint('❌ No tenant or user for API key creation');
        return null;
      }

      // Generate a random API key
      final rawKey = 'sgw_${_uuid.v4().replaceAll('-', '')}';

      // Hash the key for storage
      final keyHash = sha256.convert(utf8.encode(rawKey)).toString();

      // Insert the key
      final response = await _supabase
          .schema('sms_gateway')
          .from('api_keys')
          .insert({
            'user_id': userId,
            'tenant_id': tenantId,
            'name': name,
            'key_hash': keyHash,
            'active': true,
          })
          .select()
          .single();

      final apiKey = ApiKey.fromJson(response);

      debugPrint('✅ API key created: ${apiKey.name}');
      return (rawKey: rawKey, apiKey: apiKey);
    } catch (e) {
      debugPrint('❌ Error creating API key: $e');
      return null;
    }
  }

  /// Toggle API key active status
  Future<bool> toggleApiKey(String keyId, bool active) async {
    try {
      await _supabase
          .schema('sms_gateway')
          .from('api_keys')
          .update({'active': active}).eq('id', keyId);

      debugPrint('✅ API key ${active ? 'activated' : 'deactivated'}');
      return true;
    } catch (e) {
      debugPrint('❌ Error toggling API key: $e');
      return false;
    }
  }

  /// Delete an API key
  Future<bool> deleteApiKey(String keyId) async {
    try {
      await _supabase
          .schema('sms_gateway')
          .from('api_keys')
          .delete()
          .eq('id', keyId);

      debugPrint('✅ API key deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting API key: $e');
      return false;
    }
  }

  /// Get API endpoint URL
  String getApiEndpoint() {
    // If a custom API base domain is configured, use it instead of direct Supabase edge URL
    if (AppConstants.apiBaseDomain.isNotEmpty) {
      final domain = AppConstants.apiBaseDomain.replaceAll(RegExp(r'/+$'), '');
      return '$domain/api';
    }

    // Fallback: construct edge function URL from Supabase project URL
    final supabaseUrl = _supabase.rest.url;
    final projectRef = Uri.parse(supabaseUrl).host.split('.').first;
    return 'https://$projectRef.supabase.co/functions/v1/sms-api';
  }
}
