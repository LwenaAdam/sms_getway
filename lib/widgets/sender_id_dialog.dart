import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/tenant_service.dart';
import '../core/constants.dart';

/// Shows unified dialog for requesting and managing custom Sender IDs
void showSenderIdRequestDialog(BuildContext context, {VoidCallback? onUpdated}) {
  showDialog(
    context: context,
    builder: (dialogCtx) => _SenderIdManagementDialog(onUpdated: onUpdated),
  );
}

class _SenderIdManagementDialog extends StatefulWidget {
  final VoidCallback? onUpdated;

  const _SenderIdManagementDialog({this.onUpdated});

  @override
  State<_SenderIdManagementDialog> createState() =>
      _SenderIdManagementDialogState();
}

class _SenderIdManagementDialogState extends State<_SenderIdManagementDialog> {
  final TextEditingController _senderIdController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showForm = false;
  String _activeSenderId = 'SMS_GATEWAY';
  List<Map<String, dynamic>> _existingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSender = prefs.getString('swala_sms_sender_id');
      _activeSenderId = (savedSender != null && savedSender.trim().isNotEmpty)
          ? savedSender.trim()
          : AppConstants.swalaSmsSenderId;

      String? tenantId = TenantService().tenantId;
      final user = Supabase.instance.client.auth.currentUser;

      if (tenantId == null && user != null) {
        try {
          final member = await Supabase.instance.client
              .schema('sms_gateway')
              .from('tenant_members')
              .select('tenant_id')
              .eq('user_id', user.id)
              .maybeSingle();
          tenantId = member?['tenant_id'] as String?;
        } catch (_) {}
      }

      if (tenantId != null || user != null) {
        final supabase = Supabase.instance.client;
        final filter = tenantId != null && user != null
            ? 'tenant_id.eq.$tenantId,user_id.eq.${user.id}'
            : tenantId != null
                ? 'tenant_id.eq.$tenantId'
                : 'user_id.eq.${user!.id}';

        final res = await supabase
            .schema('sms_gateway')
            .from('sender_id_requests')
            .select()
            .or(filter)
            .order('created_at', ascending: false);

        _existingRequests = List<Map<String, dynamic>>.from(res);
      }
    } catch (e) {
      debugPrint('⚠️ Error loading sender id requests: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Show form by default if there are no prior requests
          _showForm = _existingRequests.isEmpty;
        });
      }
    }
  }

  Future<void> _setActiveSenderId(String newSenderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('swala_sms_sender_id', newSenderId.trim());
    if (mounted) {
      setState(() => _activeSenderId = newSenderId.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Active Sender ID set to: $newSenderId'),
          backgroundColor: Colors.teal,
        ),
      );
    }
    widget.onUpdated?.call();
  }

  Future<void> _submitRequest() async {
    final senderId = _senderIdController.text.trim().toUpperCase();
    final businessName = _businessNameController.text.trim();
    final purpose = _purposeController.text.trim();
    final contact = _contactController.text.trim();

    if (senderId.isEmpty ||
        businessName.isEmpty ||
        purpose.isEmpty ||
        contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (senderId.length > 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sender ID must be 11 characters or less'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? tenantId = TenantService().tenantId;
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('User is not signed in. Please log in first.');
      }

      if (tenantId == null) {
        try {
          final member = await Supabase.instance.client
              .schema('sms_gateway')
              .from('tenant_members')
              .select('tenant_id')
              .eq('user_id', user.id)
              .maybeSingle();
          tenantId = member?['tenant_id'] as String?;
        } catch (_) {}
      }

      if (tenantId == null) {
        throw Exception('Workspace not found. Please refresh or re-login.');
      }

      await Supabase.instance.client
          .schema('sms_gateway')
          .from('sender_id_requests')
          .insert({
        'tenant_id': tenantId,
        'user_id': user.id,
        'sender_id': senderId,
        'business_name': businessName,
        'purpose': purpose,
        'contact_phone': contact,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      _senderIdController.clear();
      _businessNameController.clear();
      _purposeController.clear();
      _contactController.clear();

      await _loadData();

      if (mounted) {
        setState(() => _showForm = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Request for "$senderId" submitted! Our team will process and register it with TCRA.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      widget.onUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error submitting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.badge, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text(
                'Sender ID Management',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: _isLoading
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Sender ID Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.teal.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.teal, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Active Sender ID',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                                Text(
                                  _activeSenderId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_activeSenderId != 'SMS_GATEWAY')
                            TextButton(
                              onPressed: () =>
                                  _setActiveSenderId('SMS_GATEWAY'),
                              child: const Text('Reset to Default',
                                  style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Existing Requests Section (if any)
                    if (_existingRequests.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Your Requested Sender IDs',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _showForm = !_showForm);
                            },
                            icon: Icon(
                              _showForm ? Icons.remove : Icons.add,
                              size: 16,
                            ),
                            label: Text(
                              _showForm ? 'Hide Form' : 'Request Another',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ..._existingRequests.map((req) {
                        final reqId = req['sender_id'] ?? '';
                        final status =
                            (req['status'] ?? 'pending').toString().toLowerCase();
                        final isApproved = status == 'approved';
                        final isPending = status == 'pending';

                        final statusColor = isApproved
                            ? Colors.green
                            : isPending
                                ? Colors.orange
                                : Colors.red;

                        final createdAt = req['created_at'];
                        String dateStr = '';
                        if (createdAt != null) {
                          try {
                            dateStr = DateFormat('dd MMM yyyy')
                                .format(DateTime.parse(createdAt).toLocal());
                          } catch (_) {}
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          reqId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${req['business_name'] ?? ''} • $dateStr',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isApproved && _activeSenderId != reqId)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                  ),
                                  onPressed: () => _setActiveSenderId(reqId),
                                  child: const Text('Use',
                                      style: TextStyle(fontSize: 11)),
                                )
                              else if (isApproved && _activeSenderId == reqId)
                                const Chip(
                                  label: Text('In Use',
                                      style: TextStyle(fontSize: 10)),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.tealAccent,
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                    ],

                    // Request Sender ID Form
                    if (_showForm) ...[
                      const Text(
                        'A Sender ID is the custom brand name (max 11 chars) that appears on recipients\' phones instead of a phone number.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // Sender ID Input
                      TextField(
                        controller: _senderIdController,
                        decoration: const InputDecoration(
                          labelText: 'Desired Sender ID *',
                          hintText: 'e.g., MYCOMPANY',
                          helperText:
                              'Max 11 characters, alphanumeric only',
                          prefixIcon: Icon(Icons.text_fields),
                          border: OutlineInputBorder(),
                        ),
                        maxLength: 11,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 12),

                      // Business Name Input
                      TextField(
                        controller: _businessNameController,
                        decoration: const InputDecoration(
                          labelText: 'Business / Organization Name *',
                          hintText: 'Enter your business name',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Purpose Input
                      TextField(
                        controller: _purposeController,
                        decoration: const InputDecoration(
                          labelText: 'Purpose of Use *',
                          hintText:
                              'e.g., Marketing, Notifications, Alerts',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),

                      // Contact Input
                      TextField(
                        controller: _contactController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone Number *',
                          hintText: '07XXXXXXXX or 255XXXXXXXXX',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info,
                                color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Under TCRA telecom regulations, custom Sender IDs require operator approval (typically 1-2 business days). In the meantime, you can send unlimited Bulk SMS immediately using the approved default SMS_GATEWAY.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _submitRequest,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit Request'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _senderIdController.dispose();
    _businessNameController.dispose();
    _purposeController.dispose();
    _contactController.dispose();
    super.dispose();
  }
}
