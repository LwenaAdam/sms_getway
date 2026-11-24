import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/tenant_service.dart';
import '../services/palmpesa_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final PalmPesaService _palmPesa = PalmPesaService();
  final TenantService _tenantService = TenantService();

  bool _isLoading = true;
  int _monthlySmsQuota = 1000;
  int _dailySmsQuota = 100;
  int _totalSmsSent = 0;
  String _planType = 'basic';
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadBillingData();
  }

  Future<void> _loadBillingData() async {
    setState(() => _isLoading = true);
    final tenantId = _tenantService.tenantId;
    final user = Supabase.instance.client.auth.currentUser;

    if (tenantId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // 1. Fetch tenant quota and settings
      try {
        final settingsRes = await supabase
            .schema('sms_gateway')
            .from('tenant_settings')
            .select('monthly_sms_quota, daily_sms_quota, plan_type')
            .eq('tenant_id', tenantId)
            .maybeSingle();

        if (settingsRes != null) {
          _monthlySmsQuota = (settingsRes['monthly_sms_quota'] as int?) ?? 1000;
          _dailySmsQuota = (settingsRes['daily_sms_quota'] as int?) ?? 100;
          _planType = (settingsRes['plan_type'] as String?) ?? 'basic';
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching tenant_settings: $e');
      }

      // 2. Count SMS sent this month / overall for tenant
      try {
        final sentCountRes = await supabase
            .schema('sms_gateway')
            .from('sms_logs')
            .select('id')
            .eq('tenant_id', tenantId)
            .count(CountOption.exact);
        _totalSmsSent = sentCountRes.count;
      } catch (e) {
        debugPrint('⚠️ Error counting sms_logs: $e');
      }

      // 3. Fetch transaction history from payments table
      try {
        final filterQuery = user != null
            ? 'tenant_id.eq.$tenantId,user_id.eq.${user.id}'
            : 'tenant_id.eq.$tenantId';

        final paymentsRes = await supabase
            .schema('sms_gateway')
            .from('payments')
            .select()
            .or(filterQuery)
            .order('created_at', ascending: false)
            .limit(30);

        _transactions = List<Map<String, dynamic>>.from(paymentsRes);
      } catch (e) {
        debugPrint('⚠️ Error fetching payments: $e');
      }
    } catch (e) {
      debugPrint('❌ Error loading billing overview: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openCheckoutDialog({
    required String planName,
    required double amount,
    required String description,
  }) {
    final phoneController = TextEditingController();
    String detectedNetwork = 'Mobile Money (TZ)';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Checkout: $planName',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.teal.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${NumberFormat('#,###').format(amount.round())} TZS',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment Method: Mobile Money (Tanzania)',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildNetworkChip('Vodacom M-Pesa', Colors.red),
                        _buildNetworkChip('Tigo Pesa / Mixx', Colors.blue),
                        _buildNetworkChip('Airtel Money', Colors.redAccent),
                        _buildNetworkChip('HaloPesa', Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      onChanged: (val) {
                        setModalState(() {
                          detectedNetwork = _palmPesa.detectNetwork(val);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Phone Number to Charge',
                        hintText: '07XXXXXXXX or 2557XXXXXXXX',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.phone_android),
                        suffixText: detectedNetwork,
                        suffixStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A USSD push notification will pop up on your phone. Enter your PIN to approve.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final phone = phoneController.text.trim();
                                if (phone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Please enter phone number'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                });

                                final user =
                                    Supabase.instance.client.auth.currentUser;
                                final result = await _palmPesa.requestPayment(
                                  phone: phone,
                                  amount: amount,
                                  planName: planName,
                                  customerEmail: user?.email,
                                  userId: user?.id,
                                  tenantId: _tenantService.tenantId,
                                );

                                setModalState(() {
                                  isSubmitting = false;
                                });

                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);

                                if (!mounted) return;

                                if (result.success) {
                                  _showPaymentStatusWaitingDialog(
                                    transactionId: result.transactionId!,
                                    phone: phone,
                                    amount: amount,
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ ${result.message}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock_outline, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pay ${NumberFormat('#,###').format(amount.round())} TZS via Mobile Money',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPaymentStatusWaitingDialog({
    required String transactionId,
    required String phone,
    required double amount,
  }) {
    Timer? pollTimer;
    String status = 'pending';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            pollTimer ??=
                Timer.periodic(const Duration(seconds: 4), (timer) async {
              final newStatus =
                  await _palmPesa.checkPaymentStatus(transactionId);
              if (ctx.mounted) {
                setDialogState(() {
                  status = newStatus;
                });
                if (newStatus == 'completed' || newStatus == 'failed') {
                  timer.cancel();
                  if (newStatus == 'completed') {
                    await _palmPesa.creditQuotaForPayment(transactionId);
                    if (mounted) {
                      _loadBillingData();
                    }
                  }
                }
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
              children: [
                  Icon(
                    status == 'completed'
                        ? Icons.check_circle
                        : status == 'failed'
                            ? Icons.error
                            : Icons.phone_android,
                    color: status == 'completed'
                        ? Colors.green
                        : status == 'failed'
                            ? Colors.red
                            : Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status == 'completed'
                          ? 'Payment Successful!'
                          : status == 'failed'
                              ? 'Payment Failed'
                              : 'Waiting for PIN...',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'pending') ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Please check your phone ($phone).\nEnter your Mobile Money PIN on the USSD prompt to approve ${NumberFormat('#,###').format(amount.round())} TZS.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ref: $transactionId',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ] else if (status == 'completed') ...[
                    const Icon(Icons.verified, color: Colors.green, size: 52),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment received successfully!\nYour SMS balance and subscription have been updated.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ] else ...[
                    const Icon(Icons.cancel, color: Colors.red, size: 52),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment was cancelled or timed out. Please try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                if (status == 'pending')
                  TextButton(
                    onPressed: () {
                      pollTimer?.cancel();
                      Navigator.pop(dialogCtx);
                      _loadBillingData();
                    },
                    child: const Text('I will pay later / Close'),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      pollTimer?.cancel();
                      Navigator.pop(dialogCtx);
                      _loadBillingData();
                    },
                    child: const Text('Done'),
                  ),
              ],
            );
          },
        );
      },
    ).then((_) {
      pollTimer?.cancel();
      _loadBillingData();
    });
  }

  Widget _buildNetworkChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenantName = _tenantService.tenantName ?? 'Default Workspace';
    final remainingSms = (_monthlySmsQuota - _totalSmsSent).clamp(0, 999999999);
    final usagePercent = _monthlySmsQuota > 0
        ? (_totalSmsSent / _monthlySmsQuota).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & SMS Quota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Billing & Usage',
            onPressed: _loadBillingData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBillingData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Workspace & Plan Card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.business, color: Colors.teal),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tenantName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Plan: ${_planType.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _planType == 'pro'
                                          ? Colors.teal
                                          : Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Active',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SMS Consumption & Balance Dashboard Card
                    _buildConsumptionCard(
                      totalSent: _totalSmsSent,
                      monthlyQuota: _monthlySmsQuota,
                      remaining: remainingSms,
                      usagePercent: usagePercent,
                    ),
                    const SizedBox(height: 24),

                    // Pricing / Top-Up Plans Section
                    const Text(
                      'Subscription & Top-Up Packages',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Instant activation via Mobile Money (M-Pesa, Tigo Pesa, Airtel Money, HaloPesa).',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Plan Cards
                    _buildPlanCard(
                      title: 'SMS Credit Top-Up (1,000 SMS)',
                      price: '15,000 TZS',
                      period: 'one-time',
                      amount: 15000,
                      badge: 'Pay-As-You-Go',
                      isPopular: true,
                      features: [
                        '1,000 Cloud SMS Credits added instantly',
                        'Sender ID: SMS_GATEWAY included',
                        'No monthly expiration on purchased credits',
                        'REST API & Web UI access',
                      ],
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 14),

                    _buildPlanCard(
                      title: 'Starter Gateway',
                      price: '25,000 TZS',
                      period: '/ month',
                      amount: 25000,
                      badge: 'For Small Shops',
                      features: [
                        'Unlimited SIM SMS from Android device',
                        'REST API Queue Access (/api/send)',
                        '1,000 Contacts & Contact Groups',
                        'Offline-first local synchronization',
                      ],
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 14),

                    _buildPlanCard(
                      title: 'Business Pro',
                      price: '50,000 TZS',
                      period: '/ month',
                      amount: 50000,
                      badge: 'High Volume',
                      features: [
                        'Everything in Starter',
                        '100,000 Monthly Cloud SMS Quota',
                        'Custom Branded Sender ID support',
                        'High-speed background queue & Webhooks',
                        'Unlimited Contacts & API Keys',
                      ],
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 28),

                    // Transaction History Section
                    _buildTransactionHistorySection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildConsumptionCard({
    required int totalSent,
    required int monthlyQuota,
    required int remaining,
    required double usagePercent,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.teal.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.speed, color: Colors.teal, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'SMS Consumption & Quota',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Daily Limit: $_dailySmsQuota/day',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Available Credits',
                    value: NumberFormat('#,###').format(monthlyQuota),
                    unit: 'SMS',
                    color: Colors.teal,
                  ),
                ),
                Container(height: 40, width: 1, color: Colors.grey.shade300),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Sent / Consumed',
                    value: NumberFormat('#,###').format(totalSent),
                    unit: 'SMS',
                    color: Colors.blueGrey,
                  ),
                ),
                Container(height: 40, width: 1, color: Colors.grey.shade300),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Remaining Balance',
                    value: NumberFormat('#,###').format(remaining),
                    unit: 'SMS',
                    color: remaining > 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: usagePercent,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  usagePercent > 0.9
                      ? Colors.red
                      : usagePercent > 0.7
                          ? Colors.orange
                          : Colors.teal,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(usagePercent * 100).toStringAsFixed(1)}% of quota used',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '${NumberFormat('#,###').format(remaining)} SMS remaining',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$label ($unit)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTransactionHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Transaction History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_transactions.length}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Reload Transactions',
              onPressed: _loadBillingData,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Record of Mobile Money top-ups and subscription payments.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'No transactions found yet',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Payments completed via Mobile Money will appear here.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tx = _transactions[index];
              final status = (tx['status'] ?? 'pending').toString().toLowerCase();
              final amount = tx['amount'];
              final currency = tx['currency'] ?? 'TZS';
              final planName = tx['plan_name'] ?? 'SMS Plan Top-Up';
              final phone = tx['phone_number'] ?? '';
              final ref = tx['transaction_id'] ?? '';
              final rawDate = tx['created_at'];

              String formattedDate = '';
              if (rawDate != null) {
                try {
                  final dt = DateTime.parse(rawDate).toLocal();
                  formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
                } catch (_) {
                  formattedDate = rawDate.toString();
                }
              }

              final isCompleted = status == 'completed' || status == 'success';
              final isFailed = status.contains('fail') ||
                  status.contains('cancel') ||
                  status.contains('reject');

              final badgeColor = isCompleted
                  ? Colors.green
                  : isFailed
                      ? Colors.red
                      : Colors.orange;

              final badgeIcon = isCompleted
                  ? Icons.check_circle
                  : isFailed
                      ? Icons.cancel
                      : Icons.hourglass_top;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(badgeIcon, color: badgeColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    planName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${NumberFormat('#,###').format(amount is num ? amount.round() : 0)} $currency',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isCompleted
                                        ? Colors.green.shade700
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (phone.isNotEmpty)
                                  Text(
                                    'Phone: $phone',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700),
                                  ),
                                Text(
                                  'Ref: $ref',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required double amount,
    required List<String> features,
    required Color color,
    String? badge,
    bool isPopular = false,
  }) {
    return Card(
      elevation: isPopular ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPopular ? color : Colors.grey.withValues(alpha: 0.2),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  period,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 24),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  _openCheckoutDialog(
                    planName: title,
                    amount: amount,
                    description: 'Subscribe or top-up for $price',
                  );
                },
                child: Text(
                  'Pay with Mobile Money ($price)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
