import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/marketing_campaign.dart';
import '../../core/tenant_service.dart';
import '../../services/marketing_service.dart';
import 'campaign_create_screen.dart';

/// Campaign List Screen
/// Displays all marketing campaigns with stats and actions
class CampaignListScreen extends StatefulWidget {
  const CampaignListScreen({super.key});

  @override
  State<CampaignListScreen> createState() => _CampaignListScreenState();
}

class _CampaignListScreenState extends State<CampaignListScreen> {
  final _supabase = Supabase.instance.client;
  final _tenantService = TenantService();
  final _marketingService = MarketingService();
  List<MarketingCampaign> _campaigns = [];
  bool _loading = true;
  String? _error;
  bool _marketingEnabled = false;
  Map<String, dynamic>? _marketingSettings;
  bool _analyticsLoading = false;
  String? _analyticsError;
  Map<String, int> _analyticsSummary = {
    'totalCampaigns': 0,
    'activeCampaigns': 0,
    'totalContacts': 0,
    'sent': 0,
    'failed': 0,
    'skipped': 0,
    'pending': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
    _loadMarketingStatus();
  }

  Future<void> _loadMarketingStatus() async {
    try {
      final enabled = await _marketingService.isMarketingEnabled();
      final settings = await _marketingService.getSettings();
      setState(() {
        _marketingEnabled = enabled;
        _marketingSettings = settings;
      });
    } catch (e) {
      debugPrint('Error loading marketing status: $e');
    }
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _tenantService.initialize();
      final tenantId = _tenantService.currentTenant?.id;
      if (tenantId == null) {
        throw Exception('No tenant selected');
      }

      final response = await _supabase
          .schema('sms_gateway')
          .from('marketing_campaigns')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false)
          .limit(10000); // Allow up to 10k campaigns

      final campaigns = (response as List)
          .map((json) => MarketingCampaign.fromJson(json))
          .toList();

      final campaignsWithStats = await _loadCampaignStats(campaigns);

      await _loadAnalyticsSummary(campaignsWithStats);

      if (!mounted) return;
      setState(() {
        _campaigns = campaignsWithStats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAnalyticsSummary(
      List<MarketingCampaign> campaigns) async {
    if (!mounted) return;
    setState(() {
      _analyticsLoading = true;
      _analyticsError = null;
    });

    final campaignIds = campaigns.map((c) => c.id).toList();
    final totalCampaigns = campaigns.length;
    final activeCampaigns = campaigns.where((c) => c.isActive).length;
    final totalContacts = campaigns.fold(0, (sum, c) => sum + c.totalContactCount);
    final sent = campaigns.fold(0, (sum, c) => sum + c.totalSentCount);

    if (campaignIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _analyticsSummary = {
          'totalCampaigns': totalCampaigns,
          'activeCampaigns': activeCampaigns,
          'totalContacts': totalContacts,
          'sent': sent,
          'failed': 0,
          'skipped': 0,
          'pending': (totalContacts - sent).clamp(0, totalContacts),
        };
        _analyticsLoading = false;
      });
      return;
    }

    try {
      final failedResponse = await _supabase
          .schema('sms_gateway')
          .from('marketing_campaign_contacts')
          .select('id')
          .inFilter('campaign_id', campaignIds)
          .eq('status', 'failed')
          .count(CountOption.exact);

      final skippedResponse = await _supabase
          .schema('sms_gateway')
          .from('marketing_campaign_contacts')
          .select('id')
          .inFilter('campaign_id', campaignIds)
          .eq('status', 'skipped')
          .count(CountOption.exact);

      final failed = failedResponse.count;
      final skipped = skippedResponse.count;
      final pending =
          (totalContacts - sent - failed - skipped).clamp(0, totalContacts);

      if (!mounted) return;
      setState(() {
        _analyticsSummary = {
          'totalCampaigns': totalCampaigns,
          'activeCampaigns': activeCampaigns,
          'totalContacts': totalContacts,
          'sent': sent,
          'failed': failed,
          'skipped': skipped,
          'pending': pending,
        };
        _analyticsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyticsError = e.toString();
        _analyticsLoading = false;
        _analyticsSummary = {
          'totalCampaigns': totalCampaigns,
          'activeCampaigns': activeCampaigns,
          'totalContacts': totalContacts,
          'sent': sent,
          'failed': 0,
          'skipped': 0,
          'pending': (totalContacts - sent).clamp(0, totalContacts),
        };
      });
    }
  }

  Future<List<MarketingCampaign>> _loadCampaignStats(
      List<MarketingCampaign> campaigns) async {
    final updatedCampaigns = <MarketingCampaign>[];

    for (final campaign in campaigns) {
      try {
        final totalResponse = await _supabase
            .schema('sms_gateway')
            .from('marketing_campaign_contacts')
            .select('id')
            .eq('campaign_id', campaign.id)
            .count(CountOption.exact);

        final sentResponse = await _supabase
            .schema('sms_gateway')
            .from('marketing_campaign_contacts')
            .select('id')
            .eq('campaign_id', campaign.id)
            .eq('status', 'sent')
            .count(CountOption.exact);

        final totalCount = totalResponse.count;
        final sentCount = sentResponse.count;

        updatedCampaigns.add(
          campaign.copyWith(
            totalContactCount: totalCount,
            totalSentCount: sentCount,
          ),
        );
      } catch (e) {
        updatedCampaigns.add(campaign);
      }
    }

    return updatedCampaigns;
  }

  Future<void> _toggleCampaignStatus(MarketingCampaign campaign) async {
    String newStatus;
    if (campaign.isDraft) {
      newStatus = 'active'; // Activate draft campaign
    } else if (campaign.isActive) {
      newStatus = 'paused'; // Pause active campaign
    } else if (campaign.isPaused) {
      newStatus = 'active'; // Resume paused campaign
    } else {
      return; // Can't toggle completed or cancelled
    }

    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    if (newStatus == 'active' && !isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign activation runs only on Android devices'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // If activating campaign, check SMS permission on Android
    if (newStatus == 'active') {
      if (isAndroid) {
        final status = await Permission.sms.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('❌ SMS permission is required to send marketing campaigns'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return; // Don't activate without permission
        }
      }
    }

    try {
      await _supabase.schema('sms_gateway').from('marketing_campaigns').update({
        'status': newStatus,
        if (newStatus == 'active' && campaign.activatedAt == null)
          'activated_at': DateTime.now().toIso8601String(),
      }).eq('id', campaign.id);

      _loadCampaigns();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'active'
                  ? (campaign.isDraft
                      ? '✅ Campaign activated'
                      : '▶️ Campaign resumed')
                  : '⏸️ Campaign paused',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCampaign(MarketingCampaign campaign) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Campaign'),
        content: Text('Delete "${campaign.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .schema('sms_gateway')
          .from('marketing_campaigns')
          .delete()
          .eq('id', campaign.id);

      _loadCampaigns();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Campaign deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketing Campaigns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCampaigns,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CampaignCreateScreen(),
            ),
          );
          if (result == true) {
            _loadCampaigns();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Campaign'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCampaigns,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_campaigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No campaigns yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first marketing campaign',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadCampaigns();
        await _loadMarketingStatus();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _campaigns.length + 2, // +2 for status + analytics
        itemBuilder: (context, index) {
          // Status banner at top
          if (index == 0) {
            return _buildStatusBanner();
          }

          // Analytics summary
          if (index == 1) {
            return _buildAnalyticsSummary();
          }

          final campaign = _campaigns[index - 2];
          return _CampaignCard(
            campaign: campaign,
            onToggle: () => _toggleCampaignStatus(campaign),
            onDelete: () => _deleteCampaign(campaign),
            onEdit: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CampaignCreateScreen(campaign: campaign),
                ),
              );
              if (result == true) {
                _loadCampaigns();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (!_marketingEnabled) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Marketing Automation Disabled',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Campaigns won\'t send SMS. Enable in Marketing Settings.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Show daily limit status if enabled
    final dailyLimit = _marketingSettings?['daily_limit'] as int? ?? 100;
    final dailySent = _marketingSettings?['daily_sent_count'] as int? ?? 0;
    final percentage = (dailySent / dailyLimit * 100).round();

    MaterialColor statusColor = Colors.green;
    String statusText = '✅ Marketing Active';
    IconData statusIcon = Icons.check_circle;

    if (percentage >= 100) {
      statusColor = Colors.red;
      statusText = '🛑 Daily Limit Reached';
      statusIcon = Icons.block;
    } else if (percentage >= 80) {
      statusColor = Colors.orange;
      statusText = '⚠️ Approaching Daily Limit';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.shade50,
        border: Border.all(color: statusColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Today: $dailySent / $dailyLimit SMS sent ($percentage%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSummary() {
    if (_analyticsLoading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _analyticsSummary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Analytics Summary',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_analyticsError != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Some stats may be unavailable',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryStat(
                    label: 'Campaigns',
                    value: summary['totalCampaigns'] ?? 0,
                    color: Colors.blue,
                  ),
                  _SummaryStat(
                    label: 'Active',
                    value: summary['activeCampaigns'] ?? 0,
                    color: Colors.green,
                  ),
                  _SummaryStat(
                    label: 'Sent',
                    value: summary['sent'] ?? 0,
                    color: Colors.green.shade700,
                  ),
                  _SummaryStat(
                    label: 'Failed',
                    value: summary['failed'] ?? 0,
                    color: Colors.red,
                  ),
                  _SummaryStat(
                    label: 'Skipped',
                    value: summary['skipped'] ?? 0,
                    color: Colors.orange,
                  ),
                  _SummaryStat(
                    label: 'Pending',
                    value: summary['pending'] ?? 0,
                    color: Colors.blueGrey,
                  ),
                  _SummaryStat(
                    label: 'Contacts',
                    value: summary['totalContacts'] ?? 0,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final MarketingCampaign campaign;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _CampaignCard({
    required this.campaign,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  Color _getStatusColor() {
    switch (campaign.status) {
      case 'active':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (campaign.status) {
      case 'active':
        return Icons.play_circle_filled;
      case 'paused':
        return Icons.pause_circle_filled;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.drafts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Icon(_getStatusIcon(), color: _getStatusColor(), size: 20),
                const SizedBox(width: 4),
                Text(
                  campaign.statusDisplay,
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            if (campaign.totalContactCount > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: campaign.progressPercentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(_getStatusColor()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${campaign.progressPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Stats Row
            Row(
              children: [
                _StatChip(
                  icon: Icons.send,
                  label: '${campaign.totalSentCount} sent',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.pending,
                  label: '${campaign.pendingCount} pending',
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.group,
                  label: '${campaign.totalContactCount} total',
                  color: Colors.grey,
                ),
              ],
            ),

            // Daily limit indicator
            if (campaign.isActive && campaign.dailySentCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.today, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Today: ${campaign.dailySentCount}/100',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ],

            const Divider(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (campaign.isDraft) ...[
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Activate'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ] else if (campaign.isActive) ...[
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Pause'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                ] else if (campaign.isPaused) ...[
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Resume'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ],
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
