import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:sms_gateway/services/marketing_service.dart';
import 'package:sms_gateway/core/tenant_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'marketing/campaign_list_screen.dart';

/// Marketing Automation Settings Screen
///
/// Allows users to:
/// - Enable/disable marketing automation
/// - Set daily SMS limit
/// - View current status
/// - Reset counters
class MarketingSettingsScreen extends StatefulWidget {
  const MarketingSettingsScreen({super.key});

  @override
  State<MarketingSettingsScreen> createState() =>
      _MarketingSettingsScreenState();
}

class _MarketingSettingsScreenState extends State<MarketingSettingsScreen> {
  final MarketingService _marketingService = MarketingService();
  final TenantService _tenantService = TenantService();

  bool _isLoading = true;
  bool _isEnabled = false;
  int _dailyLimit = 100;
  int _dailySentCount = 0;
  String? _tenantId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // Get tenant ID
      final currentTenant = _tenantService.currentTenant;
      if (currentTenant == null) {
        throw Exception('No tenant selected');
      }
      _tenantId = currentTenant.id;

      // Load settings from Android
      final settings = await _marketingService.getSettings();
      if (settings != null && mounted) {
        setState(() {
          _isEnabled = settings['enabled'] ?? false;
          _dailyLimit = settings['daily_limit'] ?? 100;
          _dailySentCount = settings['daily_sent_count'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleMarketing(bool value) async {
    if (_tenantId == null) return;

    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    if (value && !isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marketing automation runs only on Android devices'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check SMS permission on Android when enabling
    if (value) {
      if (isAndroid) {
        final status = await Permission.sms.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    '❌ SMS permission is required for marketing automation'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return; // Don't enable without permission
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      bool success;
      if (value) {
        // Get current user's access token and ID for RLS
        final session = Supabase.instance.client.auth.currentSession;
        final accessToken = session?.accessToken;
        final userId = Supabase.instance.client.auth.currentUser?.id;

        if (userId == null) {
          throw Exception('User not authenticated');
        }

        success = await _marketingService.enableMarketing(_tenantId!, userId,
            dailyLimit: _dailyLimit, accessToken: accessToken);
      } else {
        success = await _marketingService.disableMarketing();
      }

      if (success) {
        if (!mounted) return;
        setState(() => _isEnabled = value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? '✅ Marketing automation enabled'
                  : '✅ Marketing automation disabled',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to toggle marketing');
      }
    } catch (e) {
      debugPrint('❌ Error toggling marketing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateDailyLimit(int newLimit) async {
    setState(() => _isLoading = true);

    try {
      final success = await _marketingService.setDailyLimit(newLimit);
      if (success) {
        if (!mounted) return;
        setState(() => _dailyLimit = newLimit);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Daily limit updated'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update limit');
      }
    } catch (e) {
      debugPrint('❌ Error updating limit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetCounter() async {
    setState(() => _isLoading = true);

    try {
      final success = await _marketingService.resetDailyCounter();
      if (success) {
        if (!mounted) return;
        setState(() => _dailySentCount = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Counter reset'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to reset counter');
      }
    } catch (e) {
      debugPrint('❌ Error resetting counter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forceCheck() async {
    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    if (!isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Campaign checks run only on Android devices'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if marketing is enabled first
    if (!_isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enable marketing automation first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _marketingService.forceCheckNow();
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Campaign check triggered'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to trigger check');
      }
    } catch (e) {
      debugPrint('❌ Error forcing check: $e');

      // Provide helpful error message
      String errorMsg = e.toString();
      if (errorMsg.contains('not enabled')) {
        errorMsg = 'Please enable marketing automation first';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $errorMsg'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _loadSettings(); // Reload to show updated counts
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAndroid = !kIsWeb && Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketing Automation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Marketing Automation',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Switch(
                                value: _isEnabled,
                                onChanged: isAndroid ? _toggleMarketing : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isEnabled
                                ? 'Background workers are running'
                                : (isAndroid
                                    ? 'Automation is disabled'
                                    : 'Android required for automation'),
                            style: TextStyle(
                              color: _isEnabled
                                  ? Colors.green
                                  : (isAndroid
                                      ? Colors.grey
                                      : Colors.orange.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Daily Quota Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Quota',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _dailyLimit > 0
                                ? _dailySentCount / _dailyLimit
                                : 0,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _dailySentCount >= _dailyLimit
                                  ? Colors.red
                                  : Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_dailySentCount / $_dailyLimit SMS sent today',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _resetCounter,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reset Counter'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Daily Limit Settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Limit',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Maximum SMS per day: $_dailyLimit',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Slider(
                            value: _dailyLimit.toDouble(),
                            min: 10,
                            max: 500,
                            divisions: 49,
                            label: _dailyLimit.toString(),
                            onChanged: (value) {
                              setState(() => _dailyLimit = value.toInt());
                            },
                            onChangeEnd: (value) {
                              _updateDailyLimit(value.toInt());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Manual Actions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manual Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CampaignListScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.campaign),
                            label: const Text('Manage Campaigns'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed:
                                (_isEnabled && isAndroid) ? _forceCheck : null,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(
                              _isEnabled
                                  ? (isAndroid
                                      ? 'Check Campaigns Now'
                                      : 'Android required')
                                  : 'Enable automation first',
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              backgroundColor:
                                  (_isEnabled && isAndroid) ? null : Colors.grey,
                            ),
                          ),
                          if (!isAndroid)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Automation runs only on Android devices.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          if (!_isEnabled)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                '⚠️ Toggle marketing automation ON above to use this feature',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'How it works',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Checks for campaigns every 30 minutes\n'
                            '• Sends SMS in batches (10 per check)\n'
                            '• Enforces 2 SMS per phone per 30 days\n'
                            '• Respects opt-out list\n'
                            '• Runs in background (battery optimized)',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
