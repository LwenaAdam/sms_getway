import 'dart:convert';

/// Dynamic SMS Provider Configuration
class SmsProviderConfig {
  final String id;
  final String name;
  final String slug;
  final String endpointUrl;
  final String httpMethod; // POST or GET
  final String authType; // bearer, header, basic, query
  final String authHeaderKey; // Authorization, x-api-key, api-key, etc.
  final String apiKey;
  final String? apiSecret;
  final String senderId;
  final String? bodyTemplate; // JSON template with {{phone}}, {{message}}, {{sender_id}}
  final Map<String, String>? customHeaders;
  final bool isActive;
  final bool isDefault;
  final DateTime createdAt;

  SmsProviderConfig({
    required this.id,
    required this.name,
    required this.slug,
    required this.endpointUrl,
    this.httpMethod = 'POST',
    this.authType = 'bearer',
    this.authHeaderKey = 'Authorization',
    required this.apiKey,
    this.apiSecret,
    this.senderId = 'SMS_GATEWAY',
    this.bodyTemplate,
    this.customHeaders,
    this.isActive = true,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SmsProviderConfig.fromJson(Map<String, dynamic> json) {
    Map<String, String>? headers;
    if (json['custom_headers'] != null) {
      if (json['custom_headers'] is Map) {
        headers = (json['custom_headers'] as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }

    return SmsProviderConfig(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      endpointUrl: json['endpoint_url'] ?? '',
      httpMethod: json['http_method'] ?? 'POST',
      authType: json['auth_type'] ?? 'bearer',
      authHeaderKey: json['auth_header_key'] ?? 'Authorization',
      apiKey: json['api_key'] ?? '',
      apiSecret: json['api_secret'],
      senderId: json['sender_id'] ?? 'SMS_GATEWAY',
      bodyTemplate: json['body_template'],
      customHeaders: headers,
      isActive: json['is_active'] ?? true,
      isDefault: json['is_default'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'endpoint_url': endpointUrl,
      'http_method': httpMethod,
      'auth_type': authType,
      'auth_header_key': authHeaderKey,
      'api_key': apiKey,
      'api_secret': apiSecret,
      'sender_id': senderId,
      'body_template': bodyTemplate,
      'custom_headers': customHeaders,
      'is_active': isActive,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SmsProviderConfig copyWith({
    String? name,
    String? endpointUrl,
    String? httpMethod,
    String? authType,
    String? authHeaderKey,
    String? apiKey,
    String? apiSecret,
    String? senderId,
    String? bodyTemplate,
    Map<String, String>? customHeaders,
    bool? isActive,
    bool? isDefault,
  }) {
    return SmsProviderConfig(
      id: id,
      name: name ?? this.name,
      slug: slug,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      httpMethod: httpMethod ?? this.httpMethod,
      authType: authType ?? this.authType,
      authHeaderKey: authHeaderKey ?? this.authHeaderKey,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      senderId: senderId ?? this.senderId,
      bodyTemplate: bodyTemplate ?? this.bodyTemplate,
      customHeaders: customHeaders ?? this.customHeaders,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
    );
  }
}

/// Dynamic Payment Provider Configuration
class PaymentProviderConfig {
  final String id;
  final String name;
  final String slug;
  final String baseUrl;
  final String endpointUrl;
  final String? merchantId; // User ref or account ID (e.g. USR-579470B9AB51)
  final String apiToken;
  final String? apiSecret;
  final String currency; // TZS, USD, KES, etc.
  final String paymentType; // mobile_money_ussd, checkout_url, manual_lipa_namba
  final List<String> supportedChannels; // M-Pesa, Tigo Pesa, Airtel, HaloPesa
  final String? callbackUrl;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final bool isDefault;
  final DateTime createdAt;

  PaymentProviderConfig({
    required this.id,
    required this.name,
    required this.slug,
    required this.baseUrl,
    required this.endpointUrl,
    this.merchantId,
    required this.apiToken,
    this.apiSecret,
    this.currency = 'TZS',
    this.paymentType = 'mobile_money_ussd',
    this.supportedChannels = const ['Vodacom M-Pesa', 'Tigo Pesa', 'Airtel Money', 'HaloPesa'],
    this.callbackUrl,
    this.metadata,
    this.isActive = true,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PaymentProviderConfig.fromJson(Map<String, dynamic> json) {
    List<String> channels = ['Vodacom M-Pesa', 'Tigo Pesa', 'Airtel Money', 'HaloPesa'];
    if (json['supported_channels'] != null) {
      if (json['supported_channels'] is List) {
        channels = (json['supported_channels'] as List).map((e) => e.toString()).toList();
      } else if (json['supported_channels'] is String) {
        try {
          channels = (jsonDecode(json['supported_channels']) as List).map((e) => e.toString()).toList();
        } catch (_) {}
      }
    }

    return PaymentProviderConfig(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      baseUrl: json['base_url'] ?? '',
      endpointUrl: json['endpoint_url'] ?? '',
      merchantId: json['merchant_id'],
      apiToken: json['api_token'] ?? '',
      apiSecret: json['api_secret'],
      currency: json['currency'] ?? 'TZS',
      paymentType: json['payment_type'] ?? 'mobile_money_ussd',
      supportedChannels: channels,
      callbackUrl: json['callback_url'],
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : null,
      isActive: json['is_active'] ?? true,
      isDefault: json['is_default'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'base_url': baseUrl,
      'endpoint_url': endpointUrl,
      'merchant_id': merchantId,
      'api_token': apiToken,
      'api_secret': apiSecret,
      'currency': currency,
      'payment_type': paymentType,
      'supported_channels': supportedChannels,
      'callback_url': callbackUrl,
      'metadata': metadata,
      'is_active': isActive,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PaymentProviderConfig copyWith({
    String? name,
    String? baseUrl,
    String? endpointUrl,
    String? merchantId,
    String? apiToken,
    String? apiSecret,
    String? currency,
    String? paymentType,
    List<String>? supportedChannels,
    String? callbackUrl,
    Map<String, dynamic>? metadata,
    bool? isActive,
    bool? isDefault,
  }) {
    return PaymentProviderConfig(
      id: id,
      name: name ?? this.name,
      slug: slug,
      baseUrl: baseUrl ?? this.baseUrl,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      merchantId: merchantId ?? this.merchantId,
      apiToken: apiToken ?? this.apiToken,
      apiSecret: apiSecret ?? this.apiSecret,
      currency: currency ?? this.currency,
      paymentType: paymentType ?? this.paymentType,
      supportedChannels: supportedChannels ?? this.supportedChannels,
      callbackUrl: callbackUrl ?? this.callbackUrl,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
    );
  }
}
