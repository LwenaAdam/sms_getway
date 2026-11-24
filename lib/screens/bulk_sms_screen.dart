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
