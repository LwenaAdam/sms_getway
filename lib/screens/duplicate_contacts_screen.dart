import 'package:flutter/material.dart';
import '../contacts/contact_model.dart';
import '../services/local_data_service.dart';
import '../core/theme.dart';
import '../core/phone_validator.dart';

/// Screen to detect and merge duplicate contacts based on phone numbers
class DuplicateContactsScreen extends StatefulWidget {
  const DuplicateContactsScreen({super.key});

  @override
  State<DuplicateContactsScreen> createState() =>
      _DuplicateContactsScreenState();
}

class _DuplicateContactsScreenState extends State<DuplicateContactsScreen> {
  bool isLoading = false;
  List<DuplicateGroup> duplicateGroups = [];
  Map<String, String> selectedToKeep = {}; // groupKey -> contactId to keep

  @override
  void initState() {
    super.initState();
    _detectDuplicates();
  }

  /// Detect duplicate contacts by normalized phone number
  Future<void> _detectDuplicates() async {
    setState(() => isLoading = true);

    try {
      final contacts = await LocalDataService().getContacts();

      // Group contacts by normalized phone number
      final Map<String, List<Contact>> phoneGroups = {};

      for (final contact in contacts) {
        final normalized = PhoneValidator.normalize(contact.phoneNumber);
        if (normalized != null) {
          phoneGroups.putIfAbsent(normalized, () => []).add(contact);
        }
      }

      // Filter groups that have duplicates (more than 1 contact)
      final duplicates = <DuplicateGroup>[];
      phoneGroups.forEach((phone, contacts) {
        if (contacts.length > 1) {
          duplicates.add(DuplicateGroup(
            normalizedPhone: phone,
            contacts: contacts,
          ));
        }
      });

      // Sort by number of duplicates (most duplicates first)
      duplicates.sort((a, b) => b.contacts.length.compareTo(a.contacts.length));

      // Initialize selected contacts (default to first contact in each group)
      for (final group in duplicates) {
        selectedToKeep[group.normalizedPhone] = group.contacts.first.id;
      }

      if (mounted) {
        setState(() {
          duplicateGroups = duplicates;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error detecting duplicates: $e')),
        );
      }
    }
  }

  /// Merge duplicates - keep selected contacts and delete others
  Future<void> _mergeDuplicates() async {
    if (selectedToKeep.isEmpty) return;

    // Confirm action
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge Duplicates'),
        content: Text(
          'This will merge ${duplicateGroups.length} duplicate groups.\n\n'
          'The selected contacts will be kept, and all other duplicates will be deleted.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text('Merging ${duplicateGroups.length} groups...'),
          ],
        ),
      ),
    );

    try {
      int merged = 0;
      int deleted = 0;
      int errors = 0;

      for (final group in duplicateGroups) {
        final keepId = selectedToKeep[group.normalizedPhone];
        if (keepId == null) continue;

        try {
          // Delete all contacts except the one to keep
          for (final contact in group.contacts) {
            if (contact.id != keepId) {
              await LocalDataService().deleteContact(contact.id);
              deleted++;
            }
          }
          merged++;
        } catch (e) {
          errors++;
          debugPrint('Error merging group ${group.normalizedPhone}: $e');
        }
      }

      // Close progress dialog
      if (mounted) Navigator.pop(context);

      // Show result and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errors == 0
                  ? 'Merged $merged groups ($deleted contacts deleted)'
                  : 'Merged $merged groups, $errors errors',
            ),
            backgroundColor: errors == 0 ? Colors.green : Colors.orange,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Contacts'),
        elevation: 0,
        actions: [
          if (duplicateGroups.isNotEmpty)
            TextButton.icon(
              onPressed: _mergeDuplicates,
              icon: const Icon(Icons.merge_type, color: Colors.white),
              label: const Text(
                'Merge All',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Detecting duplicates...'),
          ],
        ),
      );
    }

    if (duplicateGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Duplicates Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All contacts have unique phone numbers',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary card
        Container(
          margin: const EdgeInsets.all(AppTheme.paddingMedium),
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${duplicateGroups.length} Duplicate Groups Found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select which contact to keep for each group',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Duplicate groups list
        Expanded(
          child: ListView.builder(
            itemCount: duplicateGroups.length,
            itemBuilder: (context, index) {
              final group = duplicateGroups[index];
              return _buildDuplicateGroupCard(group);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateGroupCard(DuplicateGroup group) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingMedium,
        vertical: AppTheme.paddingSmall,
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.2),
          child: Text(
            '${group.contacts.length}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
        title: Text(
          group.normalizedPhone,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${group.contacts.length} duplicates found',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select which contact to keep:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                ...group.contacts.map((contact) {
                  final isSelected =
                      selectedToKeep[group.normalizedPhone] == contact.id;
                  return _buildContactOption(group, contact, isSelected);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption(
      DuplicateGroup group, Contact contact, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
      ),
      child: RadioListTile<String>(
        value: contact.id,
        groupValue: selectedToKeep[group.normalizedPhone],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              selectedToKeep[group.normalizedPhone] = value;
            });
          }
        },
        title: Text(
          contact.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Phone: ${contact.phoneNumber}'),
            if (contact.firstName != null || contact.lastName != null)
              Text(
                'Name parts: ${contact.firstName ?? ''} ${contact.lastName ?? ''}'
                    .trim(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            Text(
              'Created: ${_formatDate(contact.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        activeColor: AppTheme.primaryColor,
        dense: true,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}

/// Represents a group of duplicate contacts with the same phone number
class DuplicateGroup {
  final String normalizedPhone;
  final List<Contact> contacts;

  DuplicateGroup({
    required this.normalizedPhone,
    required this.contacts,
  });
}
