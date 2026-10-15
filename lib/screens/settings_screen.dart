import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/theme_provider.dart';
import '../core/tenant_service.dart';
import '../services/local_data_service.dart';
import '../services/sync_service.dart';
import '../services/api_sms_queue_service.dart';
import '../services/settings_backup_service.dart';
import '../main.dart';
import 'profile_screen.dart';
import 'tenant_selector_screen.dart';
import 'api_settings_screen.dart';
import 'marketing_settings_screen.dart';

// SMS Channel options
enum SmsChannel { thisPhone, quickSMS }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? userEmail;
  String? userId;
  SmsChannel selectedChannel = SmsChannel.thisPhone;
  bool autoStartApiQueue = false;
  bool notificationsEnabled = true;
  final TenantService _tenantService = TenantService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadChannelPreference();
    _loadAutoStartPreference();
    _loadNotificationPreference();
  }

  void _loadUserInfo() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email;
        userId = user.id;
      });
    }
  }

  void _loadChannelPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedChannel = prefs.getString('sms_channel') ?? 'thisPhone';
      setState(() {
        selectedChannel = savedChannel == 'quickSMS'
            ? SmsChannel.quickSMS
            : SmsChannel.thisPhone;
      });
      debugPrint('✅ Loaded SMS channel: $savedChannel');
    } catch (e) {
      debugPrint('❌ Error loading channel preference: $e');
    }
  }

  void _loadAutoStartPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('api_queue_auto_start') ?? false;
      setState(() {
        autoStartApiQueue = saved;
      });
      debugPrint('✅ Loaded API queue auto-start: $saved');
    } catch (e) {
      debugPrint('❌ Error loading auto-start preference: $e');
    }
  }

  void _loadNotificationPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onSent = prefs.getBool('notification_on_sms_sent') ?? true;
      final onFailed = prefs.getBool('notification_on_sms_failed') ?? true;
      setState(() {
        notificationsEnabled = onSent && onFailed;
      });
      debugPrint('✅ Loaded notification preferences');
    } catch (e) {
      debugPrint('❌ Error loading notification preferences: $e');
    }
  }

  void _saveChannelPreference(SmsChannel channel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelName =
          channel == SmsChannel.quickSMS ? 'quickSMS' : 'thisPhone';
      await prefs.setString('sms_channel', channelName);
      setState(() {
        selectedChannel = channel;
      });
      debugPrint('✅ Saved SMS channel: $channelName');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Channel changed to: ${channel.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving channel: $e')),
        );
      }
      debugPrint('❌ Error saving channel preference: $e');
    }
  }

  void _saveAutoStartPreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('api_queue_auto_start', value);
      setState(() {
        autoStartApiQueue = value;
      });
      debugPrint('✅ Saved API queue auto-start: $value');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Auto-start enabled - Queue will start on app launch'
                  : 'Auto-start disabled - Start processing manually when needed',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preference: $e')),
        );
      }
      debugPrint('❌ Error saving auto-start preference: $e');
    }
  }

  void _saveNotificationPreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_on_sms_sent', value);
      await prefs.setBool('notification_on_sms_failed', value);
      setState(() {
        notificationsEnabled = value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Notifications enabled' : 'Notifications disabled',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving notification preference: $e')),
        );
      }
      debugPrint('❌ Error saving notification preference: $e');
    }
  }

  void _showChannelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select SMS Channel'),
        content: RadioGroup<SmsChannel>(
          groupValue: selectedChannel,
          onChanged: (channel) {
            if (channel != null) {
              _saveChannelPreference(channel);
              Navigator.pop(context);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile<SmsChannel>(
                title: Text('This Phone'),
                subtitle: Text('Send SMS using device SIM'),
                value: SmsChannel.thisPhone,
              ),
              RadioListTile<SmsChannel>(
                title: Text('QuickSMS'),
                subtitle: Text('Send SMS using QuickSMS API'),
                value: SmsChannel.quickSMS,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help with SMS Gateway Pro?'),
            SizedBox(height: 12),
            Text('Email: support@example.com'),
            Text('Docs: See API_DOCUMENTATION.md in the project'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _switchWorkspace() {
    if (_tenantService.tenantsCount < 2) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => TenantSelectorScreen(
          tenants: _tenantService.tenants,
        ),
      ),
      (route) => false,
    );
  }

  void _logout() async {
    try {
      // Clear tenant data first
      await _tenantService.clear();
      // Then sign out
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        // Navigate to AuthWrapper which handles login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  void _showSenderIdRequestDialog() {
    final TextEditingController senderIdController = TextEditingController();
    final TextEditingController businessNameController =
        TextEditingController();
    final TextEditingController purposeController = TextEditingController();
    final TextEditingController contactController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.badge, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Request Sender ID'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A Sender ID is the name that appears as the sender of your SMS messages. Custom Sender IDs help build trust and brand recognition.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Sender ID Input
              TextField(
                controller: senderIdController,
                decoration: const InputDecoration(
                  labelText: 'Desired Sender ID *',
                  hintText: 'e.g., MYCOMPANY',
                  helperText: 'Max 11 characters, alphanumeric only',
                  prefixIcon: Icon(Icons.text_fields),
                ),
                maxLength: 11,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 8),

              // Business Name Input
              TextField(
                controller: businessNameController,
                decoration: const InputDecoration(
                  labelText: 'Business/Organization Name *',
                  hintText: 'Enter your business name',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 8),

              // Purpose Input
              TextField(
                controller: purposeController,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Use *',
                  hintText: 'e.g., Marketing, Notifications, Alerts',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),

              // Contact Input
              TextField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number *',
                  hintText: '+255683274343',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your request will be reviewed by our team. Approval typically takes 1-2 business days. You\'ll be notified via email.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (senderIdController.text.isEmpty ||
                  businessNameController.text.isEmpty ||
                  purposeController.text.isEmpty ||
                  contactController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              _submitSenderIdRequest(
                senderId: senderIdController.text.toUpperCase(),
                businessName: businessNameController.text,
                purpose: purposeController.text,
                contact: contactController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSenderIdRequest({
    required String senderId,
    required String businessName,
    required String purpose,
    required String contact,
  }) async {
    try {
      final tenantId = _tenantService.tenantId;
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (tenantId == null || userId == null) {
        throw Exception('User or tenant not found');
      }

      // Store request in Supabase
      await Supabase.instance.client
          .schema('sms_gateway')
          .from('sender_id_requests')
          .insert({
        'tenant_id': tenantId,
        'user_id': userId,
        'sender_id': senderId,
        'business_name': businessName,
        'purpose': purpose,
        'contact_phone': contact,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sender ID request submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }

      debugPrint('✅ Sender ID request submitted: $senderId');
    } catch (e) {
      debugPrint('❌ Error submitting Sender ID request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(lastSync);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: AppTheme.paddingMedium),

          // Current Workspace Section
          if (_tenantService.hasTenant) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _tenantService.tenantName?.isNotEmpty == true
                            ? _tenantService.tenantName![0].toUpperCase()
                            : 'O',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Workspace',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tenantService.tenantName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_tenantService.tenantsCount >= 2)
                    TextButton(
                      onPressed: _switchWorkspace,
                      child: const Text('Switch'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
          ],

          // Settings Options
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: _saveNotificationPreference,
            ),
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Dark Mode'),
                trailing: Opacity(
                  opacity: themeProvider.isLoading ? 0.5 : 1.0,
                  child: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: themeProvider.isLoading
                        ? null // Disable switch while loading
                        : (value) async {
                            await themeProvider.toggleTheme();
                          },
                  ),
                ),
              );
            },
          ),
          const Divider(),
          // SMS Channel Selection
          ListTile(
            leading: const Icon(Icons.sms),
            title: const Text('SMS Channel'),
            subtitle: Text(
              selectedChannel == SmsChannel.quickSMS
                  ? 'QuickSMS'
                  : 'This Phone',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChannelDialog,
          ),

          // API Settings Section
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'API & Queue Settings',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          // API Integration
          ListenableBuilder(
            listenable: ApiSmsQueueService(),
            builder: (context, _) {
              final apiService = ApiSmsQueueService();
              return ListTile(
                leading: const Icon(Icons.api),
                title: const Text('API Integration'),
                subtitle: Text(
                  apiService.isEnabled
                      ? 'Active - ${apiService.pendingCount} pending'
                      : 'Manage API keys & queue',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (apiService.pendingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${apiService.pendingCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ApiSettingsScreen(),
                    ),
                  );
                },
              );
            },
          ),

          // Auto-start API Queue
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Auto-start Queue Processing'),
            subtitle:
                const Text('Automatically process SMS requests on app launch'),
            trailing: Switch(
              value: autoStartApiQueue,
              onChanged: _saveAutoStartPreference,
            ),
          ),

          // Queue Processing Status
          ListenableBuilder(
            listenable: ApiSmsQueueService(),
            builder: (context, _) {
              final apiService = ApiSmsQueueService();
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: apiService.isEnabled
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: apiService.isEnabled ? Colors.green : Colors.grey,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      apiService.isEnabled ? Icons.check_circle : Icons.info,
                      color: apiService.isEnabled ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        apiService.isEnabled
                            ? 'Queue is active and processing'
                            : 'Queue is inactive - tap "API Integration" to manage',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              apiService.isEnabled ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(),

          // Marketing Automation Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Marketing Automation',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.campaign, color: AppTheme.primaryColor),
            title: const Text('Marketing Settings'),
            subtitle: const Text('Automated SMS campaigns & scheduling'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MarketingSettingsScreen(),
                ),
              );
            },
          ),

          const Divider(),

          // Sender ID Request Section
          ListTile(
            leading: const Icon(Icons.badge, color: AppTheme.primaryColor),
            title: const Text('Sender ID Management'),
            subtitle: const Text('Request custom Sender ID for your SMS'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showSenderIdRequestDialog();
            },
          ),

          const Divider(),

          // Sync Section
          ListenableBuilder(
            listenable: SyncService(),
            builder: (syncContext, _) {
              final syncService = SyncService();
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      syncService.isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: syncService.isOnline ? Colors.green : Colors.grey,
                    ),
                    title: const Text('Sync Status'),
                    subtitle: Text(
                      syncService.isOnline
                          ? (syncService.isSyncing
                              ? 'Syncing...'
                              : 'Connected - Last synced: ${_formatLastSync(syncService.lastSyncTime)}')
                          : 'Offline - Changes will sync when online',
                    ),
                    trailing: syncService.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.sync),
                            onPressed: syncService.isOnline
                                ? () async {
                                    await LocalDataService().syncNow();
                                    if (syncContext.mounted) {
                                      ScaffoldMessenger.of(syncContext)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('Sync completed')),
                                      );
                                    }
                                  }
                                : null,
                          ),
                  ),
                  FutureBuilder<int>(
                    future: LocalDataService().getPendingSyncCount(),
                    builder: (context, snapshot) {
                      final pendingCount = snapshot.data ?? 0;
                      if (pendingCount > 0) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pending,
                                  color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '$pendingCount pending change${pendingCount > 1 ? 's' : ''} waiting to sync',
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              );
            },
          ),
          const Divider(),

          // Settings Backup Section
          ListenableBuilder(
            listenable: SettingsBackupService(),
            builder: (backupContext, _) {
              final backupService = SettingsBackupService();
              final isLoading = backupService.isSyncing;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Settings Backup',
                      style: Theme.of(backupContext).textTheme.labelMedium?.copyWith(
                            color: Theme.of(backupContext).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),

                  // Backup to Supabase Button
                  ListTile(
                    leading: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    title: const Text('Backup Settings to Supabase'),
                    subtitle: Text(
                      backupService.lastSyncStatus ??
                          'Save your settings to the cloud',
                    ),
                    trailing:
                        !isLoading ? const Icon(Icons.chevron_right) : null,
                    onTap: isLoading
                        ? null
                        : () async {
                            if (userId == null) {
                              if (backupContext.mounted) {
                                ScaffoldMessenger.of(backupContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('User not authenticated'),
                                  ),
                                );
                              }
                              return;
                            }

                            final tenantId = _tenantService.tenantId;
                            if (tenantId == null) {
                              if (backupContext.mounted) {
                                ScaffoldMessenger.of(backupContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('No tenant selected'),
                                  ),
                                );
                              }
                              return;
                            }

                            setState(() {});
                            final success =
                                await backupService.backupAllSettings(
                              userId: userId!,
                              tenantId: tenantId,
                            );

                            if (backupContext.mounted) {
                              ScaffoldMessenger.of(backupContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? '✅ Settings backed up successfully'
                                        : '❌ Error backing up settings',
                                  ),
                                  backgroundColor:
                                      success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                  ),

                  // Restore from Supabase Button
                  ListTile(
                    leading: const Icon(Icons.cloud_download),
                    title: const Text('Restore Settings from Supabase'),
                    subtitle: Text(
                      'Last synced: ${backupService.getSyncStatusMessage()}',
                    ),
                    trailing:
                        !isLoading ? const Icon(Icons.chevron_right) : null,
                    onTap: isLoading
                        ? null
                        : () async {
                            if (userId == null) {
                              if (backupContext.mounted) {
                                ScaffoldMessenger.of(backupContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('User not authenticated'),
                                  ),
                                );
                              }
                              return;
                            }

                            final tenantId = _tenantService.tenantId;
                            if (tenantId == null) {
                              if (backupContext.mounted) {
                                ScaffoldMessenger.of(backupContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('No tenant selected'),
                                  ),
                                );
                              }
                              return;
                            }

                            setState(() {});
                            final success =
                                await backupService.restoreAllSettings(
                              userId: userId!,
                              tenantId: tenantId,
                            );

                            if (backupContext.mounted) {
                              ScaffoldMessenger.of(backupContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? '✅ Settings restored successfully'
                                        : '❌ Error restoring settings',
                                  ),
                                  backgroundColor:
                                      success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                  ),

                  // Sync Status
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Settings are stored locally and backed up to Supabase for cross-device sync',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'SMS Gateway',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.sms, size: 48),
                children: [
                  const Text('Professional Bulk SMS Management System'),
                  const SizedBox(height: 16),
                  const Text('© 2024 SMS Gateway'),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showHelpDialog();
            },
          ),
          const Divider(),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Padding(
                padding: const EdgeInsets.all(AppTheme.paddingLarge),
                // Use a unique key that changes with theme to prevent animation errors
                child: ElevatedButton(
                  key: ValueKey('logout_${themeProvider.isDarkMode}'),
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.paddingMedium,
                      horizontal: AppTheme.paddingLarge,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: AppTheme.paddingSmall),
                      Text('Logout'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
