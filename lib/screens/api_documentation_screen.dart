/// API Documentation Screen
/// Standalone public documentation view for developers and guest users.
/// Does not require login, does not show internal settings/keys tabs.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import 'api_settings_screen.dart';

class ApiDocumentationScreen extends StatelessWidget {
  const ApiDocumentationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Documentation'),
        elevation: 0,
        actions: [
          if (kIsWeb)
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse('/api-docs.html');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
              label: const Text(
                'OpenAPI Docs',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: 'Open Web Docs',
              onPressed: () async {
                final uri = Uri.parse(
                    '${AppConstants.apiBaseDomain}/api-docs');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
      body: const ApiDocumentationView(isStandalone: true),
    );
  }
}

class ApiDocumentationView extends StatefulWidget {
  final bool isStandalone;

  const ApiDocumentationView({super.key, this.isStandalone = false});

  @override
  State<ApiDocumentationView> createState() => _ApiDocumentationViewState();
}

class _ApiDocumentationViewState extends State<ApiDocumentationView> {
  int _selectedLanguageIndex = 0; // 0: cURL, 1: Python, 2: JavaScript, 3: PHP

  String get _apiEndpoint {
    if (AppConstants.apiBaseDomain.isNotEmpty) {
      final domain = AppConstants.apiBaseDomain.replaceAll(RegExp(r'/+$'), '');
      return '$domain/api';
    }
    return '${AppConstants.supabaseUrl}/functions/v1/sms-api';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ $label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Supabase.instance.client.auth.currentUser;
    final isGuest = user == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              _buildHeroBanner(isDark),

              const SizedBox(height: 24),

              // Base Endpoint Card
              _buildEndpointCard(isDark),

              const SizedBox(height: 24),

              // 1. Authentication
              _buildAuthSection(isDark),

              const SizedBox(height: 32),

              // 2. Endpoints Reference
              _buildEndpointsSection(isDark),

              const SizedBox(height: 32),

              // 3. Multi-language Code Examples
              _buildCodeExamplesSection(isDark),

              const SizedBox(height: 32),

              // 4. Rate Limits & Policies
              _buildRateLimitsCard(isDark),

              const SizedBox(height: 32),

              // Guest or User Call to Action
              if (isGuest && widget.isStandalone)
                _buildGuestCtaCard(isDark)
              else if (!isGuest && widget.isStandalone)
                _buildUserCtaCard(isDark),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A5F), const Color(0xFF121E2C)]
              : [AppTheme.primaryColor.withValues(alpha: 0.08), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.blueGrey.shade800 : Colors.blue.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.terminal,
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'SMS Gateway Pro REST API',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'v1.0 LIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Automate single and bulk SMS delivery from any external app, website, or backend server.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEndpointCard(bool isDark) {
    final endpoint = _apiEndpoint;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_queue, size: 20, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  'Base API Endpoint',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Route all your HTTP requests to this base URL:',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      endpoint,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.blue.shade300 : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy Base Endpoint',
                    color: AppTheme.primaryColor,
                    onPressed: () => _copyToClipboard(endpoint, 'API Endpoint'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Authentication',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Every request must provide an active API key using the x-api-key HTTP header. Do not share your API key publicly.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 10),
        _buildCodeBlock('x-api-key: sgw_live_xxxxxxxxxxxxxxxxxxxxxxxx', 'Header'),
      ],
    );
  }

  Widget _buildEndpointsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. API Endpoints',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Endpoint 1: Single SMS
        _buildEndpointTile(
          method: 'POST',
          methodColor: Colors.blue.shade700,
          path: '/sms-api/send',
          title: 'Send Single SMS',
          description:
              'Queues a single SMS message for fast delivery via Phone SIM or Branded Cloud Gateway.',
          requestJson: '''{
  "phone_number": "+255683274343",
  "message": "Your verification code is 482910.",
  "external_id": "order-10492",
  "priority": 1
}''',
          responseJson: '''{
  "success": true,
  "request_id": "8f3e2b1a-94d7-4e6a-bc01-9a7f3e5b1284",
  "status": "pending",
  "message": "SMS request queued successfully"
}''',
          isDark: isDark,
        ),

        const SizedBox(height: 20),

        // Endpoint 2: Bulk SMS
        _buildEndpointTile(
          method: 'POST',
          methodColor: Colors.teal.shade700,
          path: '/sms-api/bulk',
          title: 'Send Bulk SMS',
          description:
              'Broadcasts the same SMS to multiple recipient phone numbers in a single request.',
          requestJson: '''{
  "phone_numbers": [
    "+255683274343",
    "+255755123456",
    "+255712987654"
  ],
  "message": "TechWareAfrica Promo: Get 20% discount on all services this week!",
  "external_id": "campaign-summer-2026",
  "priority": 0
}''',
          responseJson: '''{
  "success": true,
  "total": 3,
  "queued": 3,
  "failed": 0,
  "requests": [
    {"phone_number": "+255683274343", "request_id": "d14f..."},
    {"phone_number": "+255755123456", "request_id": "e25a..."},
    {"phone_number": "+255712987654", "request_id": "f36b..."}
  ]
}''',
          isDark: isDark,
        ),

        const SizedBox(height: 20),

        // Endpoint 3: Status Check
        _buildEndpointTile(
          method: 'GET',
          methodColor: Colors.green.shade700,
          path: '/sms-api/status/:request_id',
          title: 'Check Delivery Status',
          description:
              'Polls the real-time processing and delivery status of a previously queued SMS request.',
          requestJson: null,
          responseJson: '''{
  "success": true,
  "request_id": "8f3e2b1a-94d7-4e6a-bc01-9a7f3e5b1284",
  "phone_number": "+255683274343",
  "status": "sent",
  "channel": "thisPhone",
  "created_at": "2026-11-27T10:00:00Z",
  "processed_at": "2026-11-27T10:00:04Z"
}''',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildEndpointTile({
    required String method,
    required Color methodColor,
    required String path,
    required String title,
    required String description,
    required String? requestJson,
    required String responseJson,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : Colors.grey.shade200,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: method == 'POST' && path.contains('send'),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: methodColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              method,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            path,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
              ),
            ),
            if (requestJson != null) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Request Body (JSON):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              _buildCodeBlock(requestJson, '$title Request JSON'),
            ],
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Response Body (200 OK):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            _buildCodeBlock(responseJson, '$title Response JSON'),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeExamplesSection(bool isDark) {
    final endpoint = _apiEndpoint;

    final languages = ['cURL', 'Python', 'Node.js', 'PHP'];

    String snippet = '';
    switch (_selectedLanguageIndex) {
      case 0: // cURL
        snippet = '''curl -X POST "$endpoint/sms-api/send" \\
  -H "Content-Type: application/json" \\
  -H "x-api-key: sgw_live_YOUR_API_KEY" \\
  -d '{
    "phone_number": "+255683274343",
    "message": "Hello from API!",
    "external_id": "test-1"
  }' ''';
        break;
      case 1: // Python
        snippet = '''import requests

url = "$endpoint/sms-api/send"
headers = {
    "Content-Type": "application/json",
    "x-api-key": "sgw_live_YOUR_API_KEY"
}
payload = {
    "phone_number": "+255683274343",
    "message": "Hello from Python!",
    "external_id": "order-101"
}

response = requests.post(url, json=payload, headers=headers)
print(response.json())''';
        break;
      case 2: // Node.js
        snippet = '''// Using Fetch API (Node.js 18+)
const response = await fetch("$endpoint/sms-api/send", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "x-api-key": "sgw_live_YOUR_API_KEY"
  },
  body: JSON.stringify({
    phone_number: "+255683274343",
    message: "Hello from Node.js!",
    external_id: "order-102"
  })
});

const data = await response.json();
console.log(data);''';
        break;
      case 3: // PHP
        snippet = '''<?php
\$url = "$endpoint/sms-api/send";
\$data = [
    "phone_number" => "+255683274343",
    "message" => "Hello from PHP!",
    "external_id" => "order-103"
];

\$ch = curl_init(\$url);
curl_setopt(\$ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt(\$ch, CURLOPT_POST, true);
curl_setopt(\$ch, CURLOPT_POSTFIELDS, json_encode(\$data));
curl_setopt(\$ch, CURLOPT_HTTPHEADER, [
    "Content-Type: application/json",
    "x-api-key: sgw_live_YOUR_API_KEY"
]);

\$response = curl_exec(\$ch);
curl_close(\$ch);
echo \$response;
?>''';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. Code Examples',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Select your preferred language to see integration examples:',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(languages.length, (index) {
              final isSelected = _selectedLanguageIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(languages[index]),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedLanguageIndex = index);
                    }
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        _buildCodeBlock(snippet, '${languages[_selectedLanguageIndex]} Code'),
      ],
    );
  }

  Widget _buildRateLimitsCard(bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF333333) : Colors.orange.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed,
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade800),
                const SizedBox(width: 8),
                Text(
                  'Rate Limits & Delivery Policies',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildBulletPoint('100 requests per minute per API key.'),
            _buildBulletPoint('Maximum 1,000 recipients per single bulk request.'),
            _buildBulletPoint(
                'Phone numbers should be in international E.164 format (+255...).'),
            _buildBulletPoint(
                'SIM delivery respects the local carrier throttling and plan quotas.'),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestCtaCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2836) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.blue.shade900 : Colors.blue.shade200,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.key, size: 36, color: AppTheme.primaryColor),
          const SizedBox(height: 10),
          const Text(
            'Ready to Start Sending via API?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in or create your SMS Gateway Pro account to generate your private API keys.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.login),
            label: const Text('Back to Login'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCtaCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.vpn_key, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Manage your active API keys or monitor outgoing queue.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ApiSettingsScreen(initialIndex: 0),
                ),
              );
            },
            child: const Text('Manage Keys'),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String code, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 36),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFE0E0E0),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
              tooltip: 'Copy $label',
              onPressed: () => _copyToClipboard(code, label),
            ),
          ),
        ],
      ),
    );
  }
}
