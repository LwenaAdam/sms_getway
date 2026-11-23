/// Web SMS Service - Queue SMS for processing by mobile app
/// Used on Web, iOS, and other non-Android platforms where native SMS is not available.
/// SMS requests are queued in the database and processed by an Android device
/// with the mobile app running and queue processing enabled.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/tenant_service.dart';

class WebSmsService {
  static final WebSmsService _instance = WebSmsService._internal();
  factory WebSmsService() => _instance;
  WebSmsService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  /// Queue bulk SMS for processing by mobile app
  /// Returns list of request IDs
  Future<List<String>> queueBulkSms({
    required List<String> phoneNumbers,
    required String message,
    int priority = 0,
    Map<String, dynamic>? metadata,
  }) async {
    final tenantId = TenantService().tenantId;
    if (tenantId == null) {
      throw Exception('No tenant selected');
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    debugPrint(
        '📱 [WebSMS] Queuing bulk SMS for ${phoneNumbers.length} recipients');
    debugPrint('📱 [WebSMS] Tenant: $tenantId');

    final requestIds = <String>[];
    final requests = <Map<String, dynamic>>[];

    for (final phoneNumber in phoneNumbers) {
      final requestId = _uuid.v4();
      requestIds.add(requestId);

      // Note: api_key_id is NULL for UI-initiated requests
      requests.add({
        'id': requestId,
        'tenant_id': tenantId,
        'phone_number': phoneNumber,
        'message': message,
        'status': 'pending',
        'priority': priority,
        'source': 'web_ui',
        'created_by': userId,
        'metadata': metadata ?? {},
      });
    }

    try {
      // Batch insert all requests - must use schema prefix
      await _supabase
          .schema('sms_gateway')
          .from('sms_requests')
          .insert(requests);

      debugPrint(
          '✅ [WebSMS] ${requests.length} SMS requests queued successfully');
      return requestIds;
    } catch (e) {
      debugPrint('❌ [WebSMS] Error queuing bulk SMS: $e');
      rethrow;
    }
  }
}
