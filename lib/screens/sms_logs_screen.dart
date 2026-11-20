import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/local_data_service.dart';
import '../sms/sms_log_model.dart';

class SmsLogsScreen extends StatefulWidget {
  const SmsLogsScreen({super.key});

  @override
  State<SmsLogsScreen> createState() => _SmsLogsScreenState();
}

class _SmsLogsScreenState extends State<SmsLogsScreen> {
  List<SmsLog> logs = [];
  bool isLoading = true;
  String filterStatus = 'all'; // 'all', 'sent', 'failed', 'pending'

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() async {
    try {
      // Load from local database (offline-first)
      final localLogs = await LocalDataService().getSmsLogs(
        statusFilter: filterStatus == 'all' ? null : filterStatus,
      );


      if (mounted) {
        setState(() {
          logs = localLogs;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading logs: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return '✅';
      case 'failed':
        return '❌';
      case 'pending':
        return '⏳';
      default:
        return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = filterStatus == 'all'
        ? logs
        : logs.where((log) => log.status == filterStatus).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Logs'),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter chips
                Padding(
                  padding: const EdgeInsets.all(AppTheme.paddingMedium),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: filterStatus == 'all',
                          onSelected: (selected) {
                            setState(() => filterStatus = 'all');
                            _loadLogs();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Sent'),
                          selected: filterStatus == 'sent',
                          onSelected: (selected) {
                            setState(() => filterStatus = 'sent');
                            _loadLogs();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Failed'),
                          selected: filterStatus == 'failed',
                          onSelected: (selected) {
                            setState(() => filterStatus = 'failed');
                            _loadLogs();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Pending'),
                          selected: filterStatus == 'pending',
                          onSelected: (selected) {
                            setState(() => filterStatus = 'pending');
                            _loadLogs();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Logs list
                Expanded(
                  child: filteredLogs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.mail_outline,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('No SMS logs'),
                              const SizedBox(height: 16),
                              Text(
                                'Send some SMS messages to see logs here',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: AppTheme.paddingMedium,
                                vertical: AppTheme.paddingSmall,
                              ),
                              child: ListTile(
                                leading: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    _getStatusIcon(log.status),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                                title: Text(log.phoneNumber),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      log.message.length > 50
                                          ? '${log.message.substring(0, 50)}...'
                                          : log.message,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (log.channel != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Channel: ${log.channel}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDateTime(log.createdAt),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(log.status)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    log.status.toUpperCase(),
                                    style: TextStyle(
                                      color: _getStatusColor(log.status),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                onTap: () => _showDetails(log),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _showDetails(SmsLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SMS Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Phone:', log.phoneNumber),
              const SizedBox(height: 12),
              _buildDetailRow('Status:', log.status),
              const SizedBox(height: 12),
                _buildDetailRow('Channel:', log.channel ?? 'manual'),
                const SizedBox(height: 12),
              _buildDetailRow(
                  'Sent At:', _formatDateTime(log.sentAt ?? log.createdAt)),
              const SizedBox(height: 12),
              Text(
                'Message:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(log.message),
              ),
            ],
          ),
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
