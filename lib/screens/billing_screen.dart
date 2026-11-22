import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/tenant_service.dart';
import '../services/palmpesa_service.dart';
import 'provider_management_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final PalmPesaService _palmPesa = PalmPesaService();
  final TenantService _tenantService = TenantService();

  String? _configuredToken;
  String? _configuredUserRef;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final token = await _palmPesa.getApiToken();
    final userRef = await _palmPesa.getUserRef();
    if (mounted) {
      setState(() {
        _configuredToken = token;
        _configuredUserRef = userRef;
      });
    }
  }

  void _showConfigureCredentialsDialog() {
    final tokenController = TextEditingController(text: _configuredToken ?? '');
    final userRefController = TextEditingController(
      text: _configuredUserRef?.isNotEmpty == true
          ? _configuredUserRef
          : AppConstants.palmPesaUserRef,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.teal),
            SizedBox(width: 8),
            Text('Palm Pesa API Setup'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure your Palm Pesa Tanzania gateway credentials to collect mobile money directly from customers.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: userRefController,
                decoration: const InputDecoration(
                  labelText: 'Public User Ref',
                  hintText: 'e.g. USR-579470B9AB51',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: tokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Token',
                  hintText: 'Paste your Palm Pesa API token',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Token is obtained from your Palm Pesa dashboard under Developer Options / API Token.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _palmPesa.saveCredentials(
                apiToken: tokenController.text,
                userRef: userRefController.text,
              );
              await _loadCredentials();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Palm Pesa credentials saved successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save Credentials'),
          ),
        ],
      ),
    );
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
                        Text(
                          'Checkout: $planName',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
                        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} TZS',
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
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                                      content: Text('Please enter phone number'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                });

                                final user = Supabase.instance.client.auth.currentUser;
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

                                if (!mounted) return;
                                Navigator.pop(ctx);

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
                                      action: SnackBarAction(
                                        label: 'Settings',
                                        textColor: Colors.white,
                                        onPressed: _showConfigureCredentialsDialog,
                                      ),
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
                                    'Pay ${amount.round()} TZS via PalmPesa',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
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
            // Auto poll every 5 seconds up to 60 seconds
            pollTimer ??= Timer.periodic(const Duration(seconds: 5), (timer) async {
              final newStatus = await _palmPesa.checkPaymentStatus(transactionId);
              if (ctx.mounted) {
                setDialogState(() {
                  status = newStatus;
                });
                if (newStatus == 'completed' || newStatus == 'failed') {
                  timer.cancel();
                }
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  Text(
                    status == 'completed'
                        ? 'Payment Successful!'
                        : status == 'failed'
                            ? 'Payment Failed'
                            : 'Waiting for PIN...',
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
                      'Please check your phone ($phone).\nEnter your Mobile Money PIN on the USSD prompt to approve ${amount.round()} TZS.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ref: $transactionId',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ] else if (status == 'completed') ...[
                    const Icon(Icons.verified, color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment received! Your subscription has been updated.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ] else ...[
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
                    },
                    child: const Text('I will pay later / Close'),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      pollTimer?.cancel();
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text('Done'),
                  ),
              ],
            );
          },
        );
      },
    ).then((_) => pollTimer?.cancel());
  }

  Widget _buildNetworkChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenantName = _tenantService.tenantName ?? 'Default Workspace';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Plans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub),
            tooltip: 'Manage Payment Gateways',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProviderManagementScreen(),
                ),
              ).then((_) => _loadCredentials());
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Palm Pesa Credentials',
            onPressed: _showConfigureCredentialsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workspace Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
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
                          const Text(
                            'Gateway Plan: Active (Pro Trial)',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Gateway'),
                      onPressed: _showConfigureCredentialsDialog,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Select Subscription Plan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Charge your customers or subscribe via Palm Pesa Mobile Money (M-Pesa, Tigo, Airtel, Halotel).',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Plan Cards
            _buildPlanCard(
              title: 'Starter Gateway',
              price: '25,000 TZS',
              period: '/ month',
              amount: 25000,
              badge: 'Popular for Local Shops',
              features: [
                'Unlimited SIM SMS from your device',
                'REST API Queue Access (/api/send)',
                '1,000 Contacts & Contact Groups',
                'Offline-first synchronization',
              ],
              color: Colors.blue,
            ),
            const SizedBox(height: 14),

            _buildPlanCard(
              title: 'Business Pro',
              price: '50,000 TZS',
              period: '/ month',
              amount: 50000,
              badge: 'Best Value',
              isPopular: true,
              features: [
                'Everything in Starter',
                'SwalaSMS Branded Sender ID support',
                'High-speed automated background queue',
                'Unlimited Contacts & API Keys',
                'Priority delivery routes',
              ],
              color: Colors.teal,
            ),
            const SizedBox(height: 14),

            _buildPlanCard(
              title: 'SMS Credit Top-Up (1,000 SMS)',
              price: '15,000 TZS',
              period: 'one-time',
              amount: 15000,
              badge: 'Pay-As-You-Go',
              features: [
                '1,000 SMS Credits via SwalaSMS',
                'Branded Sender ID included',
                'No monthly expiration',
                'Instant top-up to account',
              ],
              color: Colors.orange,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  'Pay with PalmPesa ($price)',
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
