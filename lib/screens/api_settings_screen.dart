/// API Settings Screen - Manage API keys and SMS queue
/// Allows users to create/manage API keys for external integrations
/// and monitor the SMS request queue.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_sms_queue_service.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _queueService = ApiSmsQueueService();

  List<ApiKey> _apiKeys = [];
  List<SmsRequest> _requests = [];
  Map<String, int> _stats = {};
  bool _isLoading = true;
  String? _newKeyRaw; // Temporary storage for newly created key

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _queueService.getApiKeys(),
        _queueService.getRequests(limit: 50),
        _queueService.getQueueStats(),
      ]);

      setState(() {
        _apiKeys = results[0] as List<ApiKey>;
        _requests = results[1] as List<SmsRequest>;
        _stats = results[2] as Map<String, int>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load data: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Settings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // Selected tab text/icon color
          unselectedLabelColor: Colors.white70, // Unselected tab color
          indicatorColor: Colors.white, // Tab indicator line color
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.key), text: 'API Keys'),
            Tab(icon: Icon(Icons.queue), text: 'Queue'),
            Tab(icon: Icon(Icons.code), text: 'Documentation'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildApiKeysTab(),
                _buildQueueTab(),
                _buildDocsTab(),
              ],
            ),
    );
  }

  // ============================================================================
  // API KEYS TAB
  // ============================================================================

  Widget _buildApiKeysTab() {
    return Column(
      children: [
        // Create new key button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCreateKeyDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create New API Key'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Show newly created key warning
        if (_newKeyRaw != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.amber),
                    const SizedBox(width: 8),
                    const Text(
                      'Save this key - it won\'t be shown again!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _newKeyRaw = null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _newKeyRaw!,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _newKeyRaw!));
                          _showSuccess('Key copied to clipboard');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // API Keys list
        Expanded(
          child: _apiKeys.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.key_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No API Keys',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create an API key to allow external\nsystems to send SMS',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _apiKeys.length,
                  itemBuilder: (context, index) {
                    final key = _apiKeys[index];
                    return _buildApiKeyCard(key);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildApiKeyCard(ApiKey key) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: key.active ? Colors.green : Colors.grey,
          child: Icon(
            key.active ? Icons.key : Icons.key_off,
            color: Colors.white,
          ),
        ),
        title: Text(key.name),
        subtitle: Text(
          key.lastUsed != null
              ? 'Last used: ${DateFormat.yMd().add_jm().format(key.lastUsed!)}'
              : 'Never used',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleKeyAction(action, key),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: key.active ? 'deactivate' : 'activate',
              child: Row(
                children: [
                  Icon(key.active ? Icons.pause : Icons.play_arrow),
                  const SizedBox(width: 8),
                  Text(key.active ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateKeyDialog() async {
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Key Name',
                hintText: 'e.g., Production Server',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'The API key will only be shown once after creation. '
              'Make sure to save it in a secure location.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final created = await _queueService.createApiKey(nameController.text);
      if (created != null) {
        setState(() {
          _newKeyRaw = created.rawKey;
          _apiKeys.insert(0, created.apiKey);
        });
        _showSuccess('API key created successfully');
      } else {
        _showError('Failed to create API key');
      }
    }
  }

  Future<void> _handleKeyAction(String action, ApiKey key) async {
    if (action == 'activate' || action == 'deactivate') {
      final success =
          await _queueService.toggleApiKey(key.id, action == 'activate');
      if (success) {
        _loadData();
        _showSuccess('API key ${action}d');
      } else {
        _showError('Failed to $action key');
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete API Key'),
          content: Text(
            'Are you sure you want to delete "${key.name}"?\n\n'
            'External systems using this key will no longer be able to send SMS.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final success = await _queueService.deleteApiKey(key.id);
        if (success) {
          setState(() => _apiKeys.removeWhere((k) => k.id == key.id));
          _showSuccess('API key deleted');
        } else {
          _showError('Failed to delete key');
        }
      }
    }
  }

  // ============================================================================
  // QUEUE TAB
  // ============================================================================

  Widget _buildQueueTab() {
    return Column(
      children: [
        // Stats cards
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildStatCard('Pending', _stats['pending'] ?? 0, Colors.orange),
              const SizedBox(width: 8),
              _buildStatCard(
                  'Processing', _stats['processing'] ?? 0, Colors.blue),
              const SizedBox(width: 8),
              _buildStatCard('Sent', _stats['sent'] ?? 0, Colors.green),
              const SizedBox(width: 8),
              _buildStatCard('Failed', _stats['failed'] ?? 0, Colors.red),
            ],
          ),
        ),

        // Queue controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: _queueService,
                  builder: (context, _) {
                    return ElevatedButton.icon(
                      onPressed: _queueService.isEnabled
                          ? _queueService.stop
                          : _queueService.start,
                      icon: Icon(
                        _queueService.isEnabled ? Icons.stop : Icons.play_arrow,
                      ),
                      label: Text(
                        _queueService.isEnabled
                            ? 'Stop Processing'
                            : 'Start Processing',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _queueService.isEnabled ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: _queueService,
                builder: (context, _) {
                  return IconButton(
                    onPressed: _queueService.isProcessing
                        ? null
                        : _queueService.processNow,
                    icon: _queueService.isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    tooltip: 'Process Now',
                  );
                },
              ),
            ],
          ),
        ),

        const Divider(height: 24),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: true,
                onSelected: (_) {},
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Pending'),
                selected: false,
                onSelected: (_) {},
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Failed'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Request list
        Expanded(
          child: _requests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No SMS Requests',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'SMS requests from external systems\nwill appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return _buildRequestCard(request);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(SmsRequest request) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'processing':
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case 'sent':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(50),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          request.phoneNumber,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          DateFormat.yMd().add_jm().format(request.createdAt),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                request.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Message:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  width: double.infinity,
                  child: Text(request.message),
                ),
                if (request.externalId != null) ...[
                  const SizedBox(height: 8),
                  Text('External ID: ${request.externalId}'),
                ],
                if (request.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                          request.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        )),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (request.status == 'pending')
                      TextButton.icon(
                        onPressed: () => _cancelRequest(request),
                        icon: const Icon(Icons.cancel,
                            color: Colors.grey, size: 16),
                        label: const Text('Cancel'),
                      ),
                    if (request.status == 'failed')
                      TextButton.icon(
                        onPressed: () => _retryRequest(request),
                        icon: const Icon(Icons.refresh,
                            color: Colors.blue, size: 16),
                        label: const Text('Retry'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRequest(SmsRequest request) async {
    final success = await _queueService.cancelRequest(request.id);
    if (success) {
      _loadData();
      _showSuccess('Request cancelled');
    } else {
      _showError('Failed to cancel request');
    }
  }

  Future<void> _retryRequest(SmsRequest request) async {
    final success = await _queueService.retryRequest(request.id);
    if (success) {
      _loadData();
      _showSuccess('Request queued for retry');
    } else {
      _showError('Failed to retry request');
    }
  }

  // ============================================================================
  // DOCUMENTATION TAB
  // ============================================================================

  Widget _buildDocsTab() {
    final endpoint = _queueService.getApiEndpoint();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Endpoint card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'API Endpoint',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            endpoint,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: endpoint));
                            _showSuccess('Endpoint copied');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Authentication
          const Text(
            'Authentication',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Include your API key in the request header:',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _buildCodeBlock('x-api-key: sgw_your_api_key_here'),

          const SizedBox(height: 24),

          // Send single SMS
          const Text(
            'Send Single SMS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('POST /sms-api/send'),
          const SizedBox(height: 8),
          _buildCodeBlock('''
{
  "phone_number": "+255683274343",
  "message": "Hello from API!",
  "external_id": "order-123",
  "priority": 0
}'''),

          const SizedBox(height: 24),

          // Send bulk SMS
          const Text(
            'Send Bulk SMS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('POST /sms-api/bulk'),
          const SizedBox(height: 8),
          _buildCodeBlock('''
{
  "phone_numbers": [
    "+255683274343",
    "+0987654321"
  ],
  "message": "Hello from API!",
  "priority": 0
}'''),

          const SizedBox(height: 24),

          // Check status
          const Text(
            'Check Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('GET /sms-api/status/:request_id'),
          const SizedBox(height: 8),
          _buildCodeBlock('''
// Response
{
  "success": true,
  "request_id": "uuid",
  "phone_number": "+255683274343",
  "status": "sent",
  "created_at": "2025-12-23T10:00:00Z",
  "processed_at": "2025-12-23T10:00:05Z"
}'''),

          const SizedBox(height: 24),

          // Rate limits
          Card(
            color: Colors.blue[50],
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Rate Limits',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('• 100 requests per minute per API key'),
                  Text('• Maximum 1000 recipients per bulk request'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.copy, color: Colors.white54, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                _showSuccess('Code copied');
              },
            ),
          ),
        ],
      ),
    );
  }
}
