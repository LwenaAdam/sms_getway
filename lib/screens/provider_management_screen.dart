import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/provider_models.dart';
import '../services/provider_manager_service.dart';

class ProviderManagementScreen extends StatefulWidget {
  const ProviderManagementScreen({super.key});

  @override
  State<ProviderManagementScreen> createState() => _ProviderManagementScreenState();
}

class _ProviderManagementScreenState extends State<ProviderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProviderManagerService _manager = ProviderManagerService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _manager.init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==================== ADD / EDIT SMS PROVIDER ====================

  void _showAddEditSmsProviderDialog([SmsProviderConfig? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final urlController = TextEditingController(text: existing?.endpointUrl ?? '');
    final apiKeyController = TextEditingController(text: existing?.apiKey ?? '');
    final senderIdController = TextEditingController(text: existing?.senderId ?? 'SMS_GATEWAY');
    final authHeaderController = TextEditingController(text: existing?.authHeaderKey ?? 'Authorization');
    final templateController = TextEditingController(
      text: existing?.bodyTemplate ??
          jsonEncode({
            'sender_id': '{{sender_id}}',
            'recipients': ['{{phone}}'],
            'message': '{{message}}',
          }),
    );

    String authType = existing?.authType ?? 'bearer';
    String httpMethod = existing?.httpMethod ?? 'POST';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add New SMS Provider' : 'Edit SMS Provider'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Presets dropdown
                  if (existing == null) ...[
                    const Text('Quick Template / Preset:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('Swala SMS', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameController.text = 'Swala SMS (Tanzania)';
                              urlController.text = 'https://swalasms.com/api/v1/sms/messages';
                              authType = 'bearer';
                              authHeaderController.text = 'Authorization';
                              senderIdController.text = 'SMS_GATEWAY';
                              templateController.text = jsonEncode({
                                'sender_id': '{{sender_id}}',
                                'recipients': ['{{phone}}'],
                                'message': '{{message}}',
                              });
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Beem Africa', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameController.text = 'Beem Africa';
                              urlController.text = 'https://apisms.beem.africa/v1/send';
                              authType = 'basic';
                              senderIdController.text = 'INFO';
                              templateController.text = jsonEncode({
                                'source_addr': '{{sender_id}}',
                                'message': '{{message}}',
                                'encoding': 0,
                                'recipients': [
                                  {'recipient_id': 1, 'dest_addr': '{{phone}}'}
                                ],
                              });
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Custom REST Webhook', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameController.text = 'My Custom SMS API';
                              urlController.text = 'https://api.example.com/v1/send';
                              authType = 'header';
                              authHeaderController.text = 'x-api-key';
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                  ],

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Provider Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(labelText: 'Endpoint URL', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: authType,
                          decoration: const InputDecoration(labelText: 'Auth Type', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'bearer', child: Text('Bearer Token')),
                            DropdownMenuItem(value: 'header', child: Text('Custom Header')),
                            DropdownMenuItem(value: 'basic', child: Text('Basic Auth')),
                            DropdownMenuItem(value: 'none', child: Text('None / Public')),
                          ],
                          onChanged: (val) => setDialogState(() => authType = val!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: httpMethod,
                          decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'POST', child: Text('POST')),
                            DropdownMenuItem(value: 'GET', child: Text('GET')),
                          ],
                          onChanged: (val) => setDialogState(() => httpMethod = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: authHeaderController,
                    decoration: const InputDecoration(labelText: 'Auth Header Key', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'API Key / Token', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: senderIdController,
                    decoration: const InputDecoration(labelText: 'Default Sender ID', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: templateController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Payload Template (JSON)',
                      hintText: 'Use {{phone}}, {{message}}, {{sender_id}}',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final provider = SmsProviderConfig(
                  id: existing?.id ?? const Uuid().v4(),
                  name: nameController.text.trim(),
                  slug: nameController.text.trim().toLowerCase().replaceAll(' ', '_'),
                  endpointUrl: urlController.text.trim(),
                  httpMethod: httpMethod,
                  authType: authType,
                  authHeaderKey: authHeaderController.text.trim(),
                  apiKey: apiKeyController.text.trim(),
                  senderId: senderIdController.text.trim(),
                  bodyTemplate: templateController.text.trim(),
                  isDefault: existing?.isDefault ?? false,
                  isActive: existing?.isActive ?? true,
                );

                await _manager.saveSmsProvider(provider);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Save Provider'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ADD / EDIT PAYMENT PROVIDER ====================

  void _showAddEditPaymentProviderDialog([PaymentProviderConfig? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final baseUrlController = TextEditingController(text: existing?.baseUrl ?? '');
    final endpointController = TextEditingController(text: existing?.endpointUrl ?? '');
    final merchantIdController = TextEditingController(text: existing?.merchantId ?? '');
    final tokenController = TextEditingController(text: existing?.apiToken ?? '');
    final currencyController = TextEditingController(text: existing?.currency ?? 'TZS');
    String paymentType = existing?.paymentType ?? 'mobile_money_ussd';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Payment Gateway' : 'Edit Payment Gateway'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existing == null) ...[
                    const Text('Quick Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('Palm Pesa Tz', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameController.text = 'Palm Pesa Tz';
                              baseUrlController.text = AppConstants.palmPesaBaseUrl;
                              endpointController.text = '/api/v2/async/payments';
                              merchantIdController.text = AppConstants.palmPesaUserRef; // USR-579470B9AB51
                              paymentType = 'mobile_money_ussd';
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Selcom Pay', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameController.text = 'Selcom Pay';
                              baseUrlController.text = 'https://api.selcom.net/v1';
                              endpointController.text = '/checkout/create-order';
                              paymentType = 'mobile_money_ussd';
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('AzamPay', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameController.text = 'AzamPay';
                              baseUrlController.text = 'https://authenticator.azampay.com';
                              endpointController.text = '/azampay/mno/checkout';
                              paymentType = 'mobile_money_ussd';
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                  ],

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Gateway Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: baseUrlController,
                    decoration: const InputDecoration(labelText: 'Base URL', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endpointController,
                    decoration: const InputDecoration(labelText: 'Payment Endpoint', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: merchantIdController,
                    decoration: const InputDecoration(
                      labelText: 'Public User Ref / Merchant ID',
                      hintText: 'e.g. USR-579470B9AB51',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tokenController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'API Token / Secret Key', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: paymentType,
                          decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'mobile_money_ussd', child: Text('USSD Push (Mobile Money)')),
                            DropdownMenuItem(value: 'checkout_url', child: Text('Hosted Checkout URL')),
                            DropdownMenuItem(value: 'manual_lipa_namba', child: Text('Manual Lipa Namba')),
                          ],
                          onChanged: (val) => setDialogState(() => paymentType = val!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: currencyController,
                          decoration: const InputDecoration(labelText: 'Currency', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final provider = PaymentProviderConfig(
                  id: existing?.id ?? const Uuid().v4(),
                  name: nameController.text.trim(),
                  slug: nameController.text.trim().toLowerCase().replaceAll(' ', '_'),
                  baseUrl: baseUrlController.text.trim(),
                  endpointUrl: endpointController.text.trim(),
                  merchantId: merchantIdController.text.trim(),
                  apiToken: tokenController.text.trim(),
                  currency: currencyController.text.trim(),
                  paymentType: paymentType,
                  isDefault: existing?.isDefault ?? false,
                  isActive: existing?.isActive ?? true,
                );

                await _manager.savePaymentProvider(provider);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Save Gateway'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TEST MODALS ====================

  void _showTestSmsDialog(SmsProviderConfig provider) {
    final phoneController = TextEditingController();
    final messageController = TextEditingController(text: 'Test message from SMS Gateway Pro!');
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('Test: ${provider.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', hintText: '07XXXXXXXX', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      setModalState(() => isTesting = true);
                      final result = await _manager.sendDynamicSms(
                        phone: phoneController.text.trim(),
                        message: messageController.text.trim(),
                        provider: provider,
                      );
                      setModalState(() => isTesting = false);

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result.message),
                          backgroundColor: result.success ? Colors.green : Colors.red,
                        ),
                      );
                      if (result.success && ctx.mounted) Navigator.pop(ctx);
                    },
              child: isTesting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Send Test SMS'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider & Gateway Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.sms), text: 'SMS Providers'),
            Tab(icon: Icon(Icons.payments), text: 'Payment Gateways'),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _manager,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildSmsProvidersTab(),
              _buildPaymentGatewaysTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSmsProvidersTab() {
    final providers = _manager.smsProviders;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add SMS Provider'),
        onPressed: () => _showAddEditSmsProviderDialog(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: providers.length,
        itemBuilder: (context, index) {
          final p = providers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: p.isDefault ? 3 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: p.isDefault ? Colors.blue : Colors.grey.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              title: Row(
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  if (p.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Text('DEFAULT', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Endpoint: ${p.endpointUrl}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('Sender ID: ${p.senderId} | Auth: ${p.authType.toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.green),
                    tooltip: 'Test Provider',
                    onPressed: () => _showTestSmsDialog(p),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey),
                    onPressed: () => _showAddEditSmsProviderDialog(p),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'default') {
                        _manager.setDefaultSmsProvider(p.id);
                      } else if (val == 'delete') {
                        _manager.deleteSmsProvider(p.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Provider', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentGatewaysTab() {
    final gateways = _manager.paymentProviders;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Payment Gateway'),
        onPressed: () => _showAddEditPaymentProviderDialog(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: gateways.length,
        itemBuilder: (context, index) {
          final g = gateways[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: g.isDefault ? 3 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: g.isDefault ? Colors.teal : Colors.grey.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              title: Row(
                children: [
                  Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  if (g.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Text('DEFAULT', style: TextStyle(color: Colors.teal, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Type: ${g.paymentType} | Currency: ${g.currency}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (g.merchantId != null && g.merchantId!.isNotEmpty)
                    Text('User Ref / Merchant: ${g.merchantId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey),
                    onPressed: () => _showAddEditPaymentProviderDialog(g),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'default') {
                        _manager.setDefaultPaymentProvider(g.id);
                      } else if (val == 'delete') {
                        _manager.deletePaymentProvider(g.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Gateway', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
