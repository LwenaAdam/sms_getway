import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/tenant_service.dart';
import '../services/local_data_service.dart';
import '../services/sms_service.dart';
import '../contacts/contact_model.dart';
import '../groups/group_model.dart';
import 'marketing/campaign_list_screen.dart';
import 'download_app_banner.dart';
import 'billing_screen.dart';
import '../widgets/sender_id_dialog.dart';

class BulkSmsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToLogs;

  const BulkSmsScreen({super.key, this.onNavigateToLogs});

  @override
  State<BulkSmsScreen> createState() => _BulkSmsScreenState();
}

class _BulkSmsScreenState extends State<BulkSmsScreen> {
  final messageController = TextEditingController();
  List<Contact> selectedContacts = [];
  List<Contact> availableContacts = [];
  List<Group> availableGroups = [];
  bool isLoading = false;
  bool isLoadingContacts = true;
  String selectedMode = 'contacts'; // 'contacts' or 'group'
  String? selectedGroupId;
  String currentChannel = 'thisPhone';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const defaultChannel = kIsWeb ? 'swalaSMS' : 'thisPhone';
      final channel = prefs.getString('sms_channel') ?? defaultChannel;

      // Load from local database (offline-first)
      final contacts = await LocalDataService().getContacts();
      final groups = await LocalDataService().getGroups();

      if (mounted) {
        setState(() {
          currentChannel = channel;
          availableContacts = contacts;
          availableGroups = groups;
          isLoadingContacts = false;
        });
      }

      // Proactively prompt for SMS permission if channel is thisPhone on Android
      if (channel == 'thisPhone' && !kIsWeb && Platform.isAndroid) {
        final status = await Permission.sms.status;
        if (!status.isGranted) {
          debugPrint('📱 Bulk SMS Screen: Proactively requesting SMS permission for thisPhone...');
          await Permission.sms.request();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _sendSms() async {
    if (messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    List<Contact> recipients = [];
    if (selectedMode == 'contacts') {
      recipients = selectedContacts;
    } else if (selectedMode == 'group' && selectedGroupId != null) {
      try {
        // Load group contacts from local database
        recipients =
            await LocalDataService().getGroupContacts(selectedGroupId!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading group members: $e')),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select recipients')),
      );
      return;
    }

    // Load selected SMS channel from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    const defaultChannel = kIsWeb ? 'swalaSMS' : 'thisPhone';
    final selectedChannel = prefs.getString('sms_channel') ?? defaultChannel;
    debugPrint('📱 Using SMS Channel: $selectedChannel');

    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    if (selectedChannel == 'thisPhone' && !isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Device SIM SMS is only available on Android. Switch to Cloud Gateway mode in Settings to send directly from Web.'),
          ),
        );
      }
      return;
    }

    setState(() => isLoading = true);

    try {
      final tenantId = TenantService().tenantId;
      if (tenantId == null) {
        throw 'No tenant selected';
      }

      final supabase = Supabase.instance.client;

      // =========================================================================
      // BUSINESS MODEL CHECK:
      // 1. Phone SIM Gateway ("thisPhone"):
      //    Limited to 100 free SMS for basic tier. Customer must subscribe
      //    (Starter 25k/mo or Pro 50k/mo) to unlock unlimited device SIM sending.
      // 2. Cloud Bulk SMS with Sender ID ("swalaSMS"):
      //    NO daily or monthly limits! Pure pay-as-you-go: just buy credits to use.
      // =========================================================================
      if (selectedChannel == 'thisPhone') {
        try {
          final settingsRes = await supabase
              .schema('sms_gateway')
              .from('tenant_settings')
              .select('plan_type')
              .eq('tenant_id', tenantId)
              .maybeSingle();

          final planType = (settingsRes?['plan_type'] as String?) ?? 'basic';
          if (planType == 'basic') {
            final countRes = await supabase
                .schema('sms_gateway')
                .from('sms_logs')
                .select('id')
                .eq('tenant_id', tenantId)
                .eq('status', 'sent')
                .eq('channel', 'thisPhone')
                .count(CountOption.exact);

            final int phoneSent = countRes.count;
            const int freePhoneLimit = 100;

            if (phoneSent >= freePhoneLimit) {
              if (mounted) {
                setState(() => isLoading = false);
                _showPhoneLimitReachedDialog(phoneSent, freePhoneLimit);
              }
              return;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error verifying phone SIM limit: $e');
        }
      } else {
        // Cloud Bulk SMS (Sender ID) - Just check credit balance (no limit!)
        try {
          final settingsRes = await supabase
              .schema('sms_gateway')
              .from('tenant_settings')
              .select('monthly_sms_quota')
              .eq('tenant_id', tenantId)
              .maybeSingle();

          final int totalCredits =
              (settingsRes?['monthly_sms_quota'] as int?) ?? 1000;

          final countRes = await supabase
              .schema('sms_gateway')
              .from('sms_logs')
              .select('id')
              .eq('tenant_id', tenantId)
              .eq('status', 'sent')
              .neq('channel', 'thisPhone')
              .count(CountOption.exact);

          final int cloudSent = countRes.count;
          final int availableCredits =
              (totalCredits - cloudSent).clamp(0, 999999999);

          if (availableCredits < recipients.length) {
            if (mounted) {
              setState(() => isLoading = false);
              _showInsufficientCreditsDialog(availableCredits, recipients.length);
            }
            return;
          }
        } catch (e) {
          debugPrint('⚠️ Error verifying cloud credits: $e');
        }
      }

      // Android SIM platform - Request SMS permission for "This Phone" channel
      if (selectedChannel == 'thisPhone') {
        final status = await Permission.sms.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('SMS permission denied')),
            );
          }
          setState(() => isLoading = false);
          return;
        }
      }

      final user = Supabase.instance.client.auth.currentUser;
      final result = await SmsService.sendBulkSms(
        phoneNumbers: recipients.map((c) => c.phoneNumber).toList(),
        message: messageController.text,
        userId: user?.id ?? 'anonymous',
        tenantId: tenantId,
      );

      final int successCount = result['success'] as int? ?? 0;
      final int failureCount = result['failed'] as int? ?? 0;

      if (mounted) {
        setState(() => isLoading = false);
        final channelDisplayName = selectedChannel == 'thisPhone'
            ? 'Local SIM Gateway (Device SIM)'
            : 'Cloud Gateway (Branded Sender ID)';

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('SMS Sent!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  failureCount == 0 ? Icons.check_circle : Icons.info,
                  color: failureCount == 0 ? Colors.green : Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text('✅ Success: $successCount'),
                const SizedBox(height: 8),
                if (failureCount > 0) Text('❌ Failed: $failureCount'),
                const SizedBox(height: 8),
                Text(
                  'Channel: $channelDisplayName',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'What would you like to do next?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  messageController.clear();
                  setState(() {
                    selectedContacts = [];
                    selectedGroupId = null;
                  });
                },
                child: const Text('Send More'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onNavigateToLogs?.call();
                },
                child: const Text('View Logs'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      debugPrint('❌ Error sending SMS: $e');
    }
  }

  void _showPhoneLimitReachedDialog(int used, int limit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phone_locked, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('SIM Limit Reached'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have sent $used free SMS through your device SIM (free limit: $limit).',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text(
              'To continue sending unlimited SMS directly from your Android phone SIM card, please upgrade to a Gateway subscription (Starter Gateway 25,000 TZS/month).\n\nAlternatively, you can switch to Cloud Gateway to send Bulk SMS with a Sender ID.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => currentChannel = 'swalaSMS');
              SharedPreferences.getInstance().then((p) => p.setString('sms_channel', 'swalaSMS'));
            },
            child: const Text('Use Cloud Gateway'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingScreen()),
              );
            },
            child: const Text('Upgrade Plan (25,000 TZS)'),
          ),
        ],
      ),
    );
  }

  void _showInsufficientCreditsDialog(int available, int required) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.credit_card_off, color: Colors.teal, size: 28),
            SizedBox(width: 8),
            Text('SMS Credits Needed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have $available Cloud SMS credits, but you selected $required recipients.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bulk SMS with Sender ID has NO monthly restrictions or daily limits — just buy credits to use!',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Top up 1,000 SMS for 15,000 TZS via Mobile Money and send instantly.',
              style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingScreen()),
              );
            },
            child: const Text('Top Up Credits (15,000 TZS)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    final bool canSendSms = currentChannel != 'thisPhone' || isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send SMS'),
        elevation: 0,
      ),
      body: isLoadingContacts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Download App Banner for web users
                  const DownloadAppBannerCompact(),
                  const SizedBox(height: AppTheme.paddingMedium),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CampaignListScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.campaign),
                      label: const Text('Marketing Campaigns'),
                    ),
                  ),
                  const SizedBox(height: AppTheme.paddingSmall),

                  // Sender ID and Channel Info Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: currentChannel == 'thisPhone'
                          ? Colors.blue.withValues(alpha: 0.08)
                          : Colors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: currentChannel == 'thisPhone'
                            ? Colors.blue.withValues(alpha: 0.3)
                            : Colors.teal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          currentChannel == 'thisPhone'
                              ? Icons.sim_card
                              : Icons.cloud_done,
                          color: currentChannel == 'thisPhone'
                              ? Colors.blue
                              : Colors.teal,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentChannel == 'thisPhone'
                                    ? 'Sending via: Android Device SIM'
                                    : 'Sending via: Cloud Gateway',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentChannel == 'thisPhone'
                                    ? 'Sender: Your SIM Phone Number (Uses phone bundle • Zero registration required)'
                                    : 'Sender ID: SMS_GATEWAY (Pre-approved default shared Sender ID • Instant sending without user registration)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              if (currentChannel != 'thisPhone') ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => showSenderIdRequestDialog(context),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.badge, size: 14, color: Colors.teal.shade800),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Want your own company brand name? Request Sender ID',
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Mode selector
                  Text(
                    'Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Contacts'),
                          selected: selectedMode == 'contacts',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedMode = 'contacts';
                                selectedGroupId = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Group'),
                          selected: selectedMode == 'group',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => selectedMode = 'group');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Group selector
                  if (selectedMode == 'group') ...[
                    Text(
                      'Select Group',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGroupId,
                      hint: const Text('Choose a group'),
                      items: availableGroups
                          .map((group) => DropdownMenuItem(
                                value: group.id,
                                child: Text(
                                  '${group.name} (${group.memberCount ?? 0} members)',
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedGroupId = value);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Individual contact selector
                  if (selectedMode == 'contacts') ...[
                    Text(
                      'Select Recipients (${selectedContacts.length} selected)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        itemCount: availableContacts.length,
                        itemBuilder: (context, index) {
                          final contact = availableContacts[index];
                          final isSelected =
                              selectedContacts.any((c) => c.id == contact.id);
                          return CheckboxListTile(
                            title: Text(contact.name),
                            subtitle: Text(contact.phoneNumber),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedContacts.add(contact);
                                } else {
                                  selectedContacts
                                      .removeWhere((c) => c.id == contact.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Message input
                  Text(
                    'Message',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Enter your message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Characters: ${messageController.text.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (isLoading || !canSendSms) ? null : _sendSms,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        isLoading
                            ? 'Sending...'
                            : (canSendSms
                                ? 'Send SMS'
                                : 'SIM Sending (Android Only)'),
                      ),
                    ),
                  ),
                  if (!canSendSms) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Device SIM sending is Android only. Switch to Cloud Gateway mode in Settings to send directly from Web.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }
}
