import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/tenant_service.dart';
import '../services/palmpesa_service.dart';
import '../widgets/sender_id_dialog.dart';
import '../widgets/responsive_layout.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final PalmPesaService _palmPesa = PalmPesaService();
  final TenantService _tenantService = TenantService();

  bool _isLoading = true;
  int _cloudSmsCredits = 0;
  int _cloudSmsSent = 0;
  int _phoneSmsSent = 0;
  int _apiQueueSent = 0;
  final int _phoneFreeLimit = 100;
  String _planType = 'basic';
  List<Map<String, dynamic>> _transactions = [];
  String? _verifyingTxId;
  int _customSmsCount = 50;
  final TextEditingController _customSmsController =
      TextEditingController(text: '50');

  @override
  void dispose() {
    _customSmsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadBillingData();
  }

  Future<void> _verifyTransaction(String transactionId) async {
    setState(() => _verifyingTxId = transactionId);
    try {
      final status = await _palmPesa.checkPaymentStatus(transactionId);
      if (!mounted) return;

      if (status == 'completed') {
        await _palmPesa.creditQuotaForPayment(transactionId);
        await _loadBillingData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Payment verified and SMS quota added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (status == 'failed') {
        await _loadBillingData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Payment failed or was cancelled by user.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏳ Payment is still pending. Please enter your PIN on your phone to complete.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verifyingTxId = null);
    }
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
      // 0. Auto-sync any pending payments from Palm Pesa gateway
      try {
        final synced = await _palmPesa.syncPendingPayments(
          tenantId: tenantId,
          userId: user?.id,
        );
        if (synced > 0) {
          debugPrint('✅ [Billing] Auto-resolved $synced pending payment(s)');
        }
      } catch (e) {
        debugPrint('⚠️ [Billing] Auto-sync error: $e');
      }

      final supabase = Supabase.instance.client;

      // 1. Fetch tenant quota and plan settings
      try {
        final settingsRes = await supabase
            .schema('sms_gateway')
            .from('tenant_settings')
            .select('monthly_sms_quota, daily_sms_quota, plan_type')
            .eq('tenant_id', tenantId)
            .maybeSingle();

        if (settingsRes != null) {
          _cloudSmsCredits =
              (settingsRes['monthly_sms_quota'] as int?) ?? 0;
          _planType = (settingsRes['plan_type'] as String?) ?? 'basic';
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching tenant_settings: $e');
      }

      // 2. Count Phone SIM vs Cloud SMS logs + API Queue Requests
      try {
        final phoneSentRes = await supabase
            .schema('sms_gateway')
            .from('sms_logs')
            .select('id')
            .eq('tenant_id', tenantId)
            .eq('status', 'sent')
            .eq('channel', 'thisPhone')
            .count(CountOption.exact);

        final cloudSentRes = await supabase
            .schema('sms_gateway')
            .from('sms_logs')
            .select('id')
            .eq('tenant_id', tenantId)
            .eq('status', 'sent')
            .neq('channel', 'thisPhone')
            .count(CountOption.exact);

        // Fetch sent requests from sms_requests (API / Queue)
        final queueSentRes = await supabase
            .schema('sms_gateway')
            .from('sms_requests')
            .select('id')
            .eq('tenant_id', tenantId)
            .eq('status', 'sent')
            .count(CountOption.exact);

        _apiQueueSent = queueSentRes.count;

        // Since the Android device acts as SIM Gateway for API queue requests:
        // Total Phone SMS sent is the maximum of logged phone SMS or queue sent (or combined)
        final int rawPhoneLogs = phoneSentRes.count;
        final int rawQueueSent = queueSentRes.count;
        _phoneSmsSent = (rawPhoneLogs > rawQueueSent)
            ? rawPhoneLogs
            : (rawPhoneLogs == 0 ? rawQueueSent : rawPhoneLogs + rawQueueSent);

        _cloudSmsSent = cloudSentRes.count;
      } catch (e) {
        debugPrint('⚠️ Error counting sms_logs by channel: $e');
      }

      // 3. Fetch transaction history from payments table & reconcile quota
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

        // Reconcile credits from actual completed transactions to prevent inflation
        int totalPaidCredits = 0;
        for (final tx in _transactions) {
          final status = (tx['status'] ?? '').toString().toLowerCase();
          if (status == 'completed') {
            final planName = (tx['plan_name'] ?? '').toString();
            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final match =
                RegExp(r'(\d[\d,]*)\s*sms', caseSensitive: false).firstMatch(planName);
            if (match != null) {
              totalPaidCredits +=
                  int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
            } else if (!planName.toLowerCase().contains('gateway') && amount > 0) {
              totalPaidCredits += (amount / 15).round();
            }
          }
        }

        // If the database has 2,000 (from the old 1,000 default bug) but user only paid for 1,000:
        if (totalPaidCredits > 0 && _cloudSmsCredits > totalPaidCredits) {
          debugPrint(
              '🔧 Reconciling inflated cloud credits: was $_cloudSmsCredits, setting to exact paid $totalPaidCredits');
          _cloudSmsCredits = totalPaidCredits;
          // Background update to correct the database row in Supabase
          supabase
              .schema('sms_gateway')
              .from('tenant_settings')
              .update({
                'monthly_sms_quota': totalPaidCredits,
                'updated_at': DateTime.now().toIso8601String()
              })
              .eq('tenant_id', tenantId)
              .catchError((_) {});
        }
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
    final remainingCloudCredits =
        (_cloudSmsCredits - _cloudSmsSent).clamp(0, 999999999);
    final isPaidGateway = _planType == 'starter' || _planType == 'pro';
    final phoneUsagePercent =
        (_phoneSmsSent / _phoneFreeLimit).clamp(0.0, 1.0);

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
                child: ResponsiveCenter(
                  maxWidth: 1000,
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
                                child: const Icon(Icons.business,
                                    color: Colors.teal),
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
                                      'Gateway Plan: ${_planType.toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isPaidGateway
                                            ? Colors.teal
                                            : Colors.orange.shade800,
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

                      // =========================================================
                      // 0. GENERAL PICTURE OF SMS & WAYS USED (OVERVIEW DASHBOARD)
                      // =========================================================
                      _buildSmsGeneralPictureCard(
                        totalPhoneSent: _phoneSmsSent,
                        totalCloudSent: _cloudSmsSent,
                        apiQueueSent: _apiQueueSent,
                        cloudCredits: remainingCloudCredits,
                        isPaidGateway: isPaidGateway,
                      ),
                      const SizedBox(height: 16),

                      // =========================================================
                      // 1. CLOUD BULK SMS CARD (SENDER ID) - ZERO LIMITS
                      // =========================================================
                      _buildCloudBulkSmsCard(
                        availableCredits: remainingCloudCredits,
                        totalSent: _cloudSmsSent,
                      ),
                      const SizedBox(height: 16),

                      // =========================================================
                      // 2. PHONE SIM GATEWAY CARD - LIMIT ENFORCEMENT
                      // =========================================================
                      _buildPhoneSimGatewayCard(
                        isPaid: isPaidGateway,
                        phoneSent: _phoneSmsSent,
                        freeLimit: _phoneFreeLimit,
                        usagePercent: phoneUsagePercent,
                      ),
                      const SizedBox(height: 24),

                      // =========================================================
                      // 3. PACKAGES (CLOUD TOP-UP & GATEWAY SUBSCRIPTION)
                      // =========================================================
                      const Text(
                        'Buy SMS Credits & Subscriptions',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pay instantly via Mobile Money (M-Pesa, Tigo Pesa, Airtel Money, HaloPesa).',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // 1. Flexible Custom SMS Credit Purchase (Buy as little as 100 SMS)
                      _buildCustomSmsPurchaseCard(),
                      const SizedBox(height: 20),

                      const Text(
                        'Device SIM Gateway Subscriptions',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Unlock unlimited phone SIM sending directly from your Android phone bundle.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      // Responsive 2-Plan layout for Phone SIM Gateway
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final starterCard = _buildPlanCard(
                            title: 'Starter Gateway',
                            price: '25,000 TZS',
                            period: '/ month',
                            amount: 25000,
                            badge: 'Unlock Unlimited Phone SIM',
                            features: [
                              'UNLIMITED SIM SMS from your Android device',
                              'Lifts the 100 free SMS limit on your phone',
                              'REST API Queue Access (/api/send)',
                              '1,000 Contacts & Groups sync',
                              'Offline-first synchronization',
                            ],
                            color: Colors.blue,
                          );

                          final proCard = _buildPlanCard(
                            title: 'Business Pro',
                            price: '50,000 TZS',
                            period: '/ month',
                            amount: 50000,
                            badge: 'High Volume Gateway',
                            features: [
                              'Everything in Starter',
                              'UNLIMITED Phone SIM Gateway sending',
                              'Custom Branded Sender ID registration support',
                              'High-speed automated background queue',
                              'Unlimited Contacts & API Keys',
                            ],
                            color: Colors.purple,
                          );

                          if (constraints.maxWidth >= 720) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: starterCard),
                                const SizedBox(width: 14),
                                Expanded(child: proCard),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                starterCard,
                                const SizedBox(height: 14),
                                proCard,
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 28),

                      // =========================================================
                      // 4. TRANSACTION HISTORY
                      // =========================================================
                      _buildTransactionHistorySection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSmsGeneralPictureCard({
    required int totalPhoneSent,
    required int totalCloudSent,
    required int apiQueueSent,
    required int cloudCredits,
    required bool isPaidGateway,
  }) {
    final int grandTotalSent = totalPhoneSent + totalCloudSent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.teal.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.analytics, color: Colors.blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SMS Usage Overview',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'General picture of SMS sent and channels used',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${NumberFormat('#,###').format(grandTotalSent)} Total Sent',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Distribution breakdown tiles
            Row(
              children: [
                Expanded(
                  child: _buildBreakdownBox(
                    icon: Icons.phone_android,
                    label: 'Device SIM',
                    value: '$totalPhoneSent',
                    subtext: isPaidGateway
                        ? 'Unlimited Active'
                        : '$totalPhoneSent / 100 Used',
                    color: (totalPhoneSent > 100 && !isPaidGateway)
                        ? Colors.red
                        : Colors.orange,
                    isExceeded: totalPhoneSent > 100 && !isPaidGateway,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildBreakdownBox(
                    icon: Icons.cloud_done,
                    label: 'Cloud Sender ID',
                    value: '$totalCloudSent',
                    subtext: '$cloudCredits Credits Left',
                    color: Colors.teal,
                    isExceeded: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildBreakdownBox(
                    icon: Icons.api,
                    label: 'API / Queue',
                    value: '$apiQueueSent',
                    subtext: 'Auto Queue',
                    color: Colors.purple,
                    isExceeded: false,
                  ),
                ),
              ],
            ),
            if (totalPhoneSent >= 100 && !isPaidGateway) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        totalPhoneSent > 100
                            ? 'Phone SIM limit exceeded ($totalPhoneSent/100 sent). Upgrade to Starter Gateway for unlimited phone sending.'
                            : '100 free Phone SIM limit reached. Upgrade to continue sending from your phone.',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownBox({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color color,
    required bool isExceeded,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExceeded ? Colors.red : color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: isExceeded ? Colors.red : color),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isExceeded ? Colors.red : color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              color: isExceeded ? Colors.red : Colors.grey,
              fontWeight: isExceeded ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudBulkSmsCard({
    required int availableCredits,
    required int totalSent,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
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
                    Icon(Icons.cloud_done, color: Colors.teal, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Cloud Bulk SMS (Sender ID)',
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
                  child: const Text(
                    'No Limit • Just Buy to Use',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Uses pre-approved Sender ID (SMS_GATEWAY). No daily limits or monthly expiration — simply buy credits to send.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Available Credits',
                    value: NumberFormat('#,###').format(availableCredits),
                    unit: 'SMS',
                    color: availableCredits > 0 ? Colors.teal : Colors.red,
                  ),
                ),
                Container(height: 40, width: 1, color: Colors.grey.shade300),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total Cloud Sent',
                    value: NumberFormat('#,###').format(totalSent),
                    unit: 'SMS',
                    color: Colors.blueGrey,
                  ),
                ),
                Container(height: 40, width: 1, color: Colors.grey.shade300),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _openCheckoutDialog(
                        planName: 'SMS Credit Top-Up (1,000 SMS)',
                        amount: 15000,
                        description:
                            'Buy 1,000 Cloud SMS credits with Sender ID (SMS_GATEWAY)',
                      );
                    },
                    child: const Text(
                      'Top Up Credits',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => showSenderIdRequestDialog(context,
                  onUpdated: _loadBillingData),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge, size: 14, color: Colors.teal.shade800),
                  const SizedBox(width: 4),
                  Text(
                    'Want your own brand name as Sender ID? Request custom Sender ID',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneSimGatewayCard({
    required bool isPaid,
    required int phoneSent,
    required int freeLimit,
    required double usagePercent,
  }) {
    final hasReachedLimit = !isPaid && phoneSent >= freeLimit;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasReachedLimit
              ? Colors.red.withValues(alpha: 0.4)
              : isPaid
                  ? Colors.blue.withValues(alpha: 0.3)
                  : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sim_card,
                      color: hasReachedLimit
                          ? Colors.red
                          : isPaid
                              ? Colors.blue
                              : Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Device SIM Gateway (Phone)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.blue.withValues(alpha: 0.1)
                        : hasReachedLimit
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPaid
                        ? 'Unlimited SIM Sending'
                        : hasReachedLimit
                            ? 'Limit Reached'
                            : 'Free Trial: $freeLimit SMS Limit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPaid
                          ? Colors.blue
                          : hasReachedLimit
                              ? Colors.red
                              : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isPaid
                  ? 'Your Android device is registered as an active Gateway with unlimited SIM sending.'
                  : 'Customer must pay once $freeLimit SMS is reached to continue using their phone as an SMS Gateway.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 22),
            if (isPaid) ...[
              Row(
                children: [
                  const Icon(Icons.verified, color: Colors.blue, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: Gateway License Active (${_planType.toUpperCase()})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '$phoneSent total SMS sent from your phone SIM card.',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Phone SMS Used: $phoneSent / $freeLimit',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: hasReachedLimit ? Colors.red : Colors.black87,
                    ),
                  ),
                  Text(
                    hasReachedLimit
                        ? (phoneSent > freeLimit
                            ? 'Limit Exceeded ($phoneSent sent)'
                            : '0 Remaining (Upgrade Required)')
                        : '${freeLimit - phoneSent} Free Remaining',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasReachedLimit ? Colors.red : Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usagePercent,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasReachedLimit ? Colors.red : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    _openCheckoutDialog(
                      planName: 'Starter Gateway',
                      amount: 25000,
                      description:
                          'Unlock unlimited Phone SIM Gateway sending for 25,000 TZS/month',
                    );
                  },
                  icon: const Icon(Icons.upgrade, size: 18),
                  label: const Text(
                    'Unlock Unlimited Phone SIM (25,000 TZS/mo)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
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
              final status =
                  (tx['status'] ?? 'pending').toString().toLowerCase();
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
                            if (!isCompleted && !isFailed && ref.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 28,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange.shade900,
                                    side: BorderSide(color: Colors.orange.shade400),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: _verifyingTxId == ref
                                      ? null
                                      : () => _verifyTransaction(ref),
                                  icon: _verifyingTxId == ref
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.refresh, size: 14),
                                  label: Text(
                                    _verifyingTxId == ref ? 'Verifying...' : 'Verify Payment Status',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildCustomSmsPurchaseCard() {
    final int totalAmount = (_customSmsCount * 15).clamp(0, 999999999);
    final presets = [15, 50, 100, 250, 500, 1000, 2500];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.teal, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt, color: Colors.teal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buy SMS Credits Freely',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'From just 15 SMS • 15 TZS per SMS',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'No Expiration',
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Quick Select SMS Quantity:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((count) {
                final isSelected = _customSmsCount == count;
                final price = NumberFormat('#,###').format(count * 15);
                return ChoiceChip(
                  label: Text('$count SMS ($price TZS)'),
                  selected: isSelected,
                  selectedColor: Colors.teal.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.teal.shade900 : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _customSmsCount = count;
                        _customSmsController.text = count.toString();
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _customSmsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Or Type Any Custom Quantity',
                hintText: 'e.g. 25',
                prefixIcon: const Icon(Icons.pin),
                suffixText: 'SMS',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                helperText:
                    'Minimum 15 SMS (225 TZS) • Instant Mobile Money Top-Up',
                isDense: true,
              ),
              onChanged: (val) {
                final count = int.tryParse(val) ?? 0;
                setState(() {
                  _customSmsCount = count;
                });
              },
            ),
            const SizedBox(height: 14),
            // Price calculation summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total to Pay (15 TZS/SMS):',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        '${NumberFormat('#,###').format(totalAmount)} TZS',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      '${NumberFormat('#,###').format(_customSmsCount)} Credits',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _customSmsCount < 15
                    ? null
                    : () {
                        final formattedCount =
                            NumberFormat('#,###').format(_customSmsCount);
                        final formattedPrice =
                            NumberFormat('#,###').format(totalAmount);
                        _openCheckoutDialog(
                          planName:
                              'SMS Credit Top-Up ($formattedCount SMS)',
                          amount: totalAmount.toDouble(),
                          description:
                              'Buy $formattedCount Cloud SMS credits for $formattedPrice TZS',
                        );
                      },
                icon: const Icon(Icons.payment, size: 20),
                label: Text(
                  _customSmsCount < 15
                      ? 'Enter at least 15 SMS (225 TZS)'
                      : 'Pay ${NumberFormat('#,###').format(totalAmount)} TZS via Mobile Money',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
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
