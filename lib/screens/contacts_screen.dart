import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../services/local_data_service.dart';
import '../services/csv_import_service.dart';
import '../contacts/contact_model.dart';
import '../groups/group_model.dart';
import '../core/tenant_service.dart';
import 'phonebook_sync_screen.dart';
import 'duplicate_contacts_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Contact> contacts = [];
  List<Contact> filteredContacts = [];
  List<Group> groups = [];
  bool isLoading = true;

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Selection mode for bulk operations
  bool isSelectionMode = false;
  Set<String> selectedContactIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Exit selection mode when switching tabs
        if (isSelectionMode) {
          setState(() {
            isSelectionMode = false;
            selectedContactIds.clear();
          });
        }
        setState(() {});
      }
    });
    _loadContacts();
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadContacts() async {
    try {
      debugPrint('📱 Loading contacts from local database');

      // Load from local database (offline-first)
      final localContacts = await LocalDataService().getContacts();

      debugPrint('✅ Loaded ${localContacts.length} contacts');

      if (mounted) {
        setState(() {
          contacts = localContacts;
          filteredContacts = localContacts;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        filteredContacts = contacts;
      } else {
        filteredContacts = contacts.where((contact) {
          return contact.name.toLowerCase().contains(_searchQuery) ||
              contact.phoneNumber.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  void _loadGroups() async {
    try {
      // Load from local database (offline-first)
      final localGroups = await LocalDataService().getGroups();

      if (mounted) {
        setState(() {
          groups = localGroups;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading groups: $e')),
        );
      }
    }
  }

  void _addContact() {
    showDialog(
      context: context,
      builder: (context) => AddContactDialog(
        onAdd: (contact) {
          _loadContacts();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _deleteContact(String id) async {
    try {
      // Delete using local data service (offline-first)
      await LocalDataService().deleteContact(id);
      _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }


  /// Toggle contact selection
  void _toggleContactSelection(String id) {
    setState(() {
      if (selectedContactIds.contains(id)) {
        selectedContactIds.remove(id);
        // Exit selection mode if no contacts selected
        if (selectedContactIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedContactIds.add(id);
      }
    });
  }

  /// Select all contacts
  void _selectAllContacts() {
    setState(() {
      if (selectedContactIds.length == filteredContacts.length) {
        // Deselect all
        selectedContactIds.clear();
      } else {
        // Select all (only from filtered contacts)
        selectedContactIds = filteredContacts.map((c) => c.id).toSet();
      }
    });
  }

  /// Delete selected contacts
  void _deleteSelectedContacts() async {
    if (selectedContactIds.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contacts'),
        content: Text(
          'Are you sure you want to delete ${selectedContactIds.length} contact${selectedContactIds.length > 1 ? 's' : ''}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
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
            Text('Deleting ${selectedContactIds.length} contacts...'),
          ],
        ),
      ),
    );

    try {
      int deleted = 0;
      int errors = 0;

      for (final id in selectedContactIds) {
        try {
          await LocalDataService().deleteContact(id);
          deleted++;
        } catch (e) {
          errors++;
          debugPrint('Error deleting contact $id: $e');
        }
      }

      // Close progress dialog
      if (mounted) Navigator.pop(context);

      // Exit selection mode
      setState(() {
        isSelectionMode = false;
        selectedContactIds.clear();
      });

      // Reload contacts
      _loadContacts();

      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errors == 0
                  ? '$deleted contact${deleted > 1 ? 's' : ''} deleted'
                  : '$deleted deleted, $errors failed',
            ),
            backgroundColor: errors == 0 ? Colors.green : Colors.orange,
          ),
        );
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

  /// Add selected contacts to a group
  void _addSelectedContactsToGroup() async {
    if (selectedContactIds.isEmpty) return;

    // Show group selection dialog
    final selectedGroup = await showDialog<Group>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select a group to add ${selectedContactIds.length} contact${selectedContactIds.length > 1 ? 's' : ''}',
            ),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'No groups available',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _createGroup();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Group'),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      leading: const Icon(Icons.group),
                      title: Text(group.name),
                      subtitle: Text('${group.memberCount} members'),
                      onTap: () => Navigator.pop(context, group),
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedGroup == null) return;

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
            Expanded(
              child: Text(
                'Adding ${selectedContactIds.length} contacts to ${selectedGroup.name}...',
              ),
            ),
          ],
        ),
      ),
    );

    try {
      int added = 0;
      int skipped = 0;
      int errors = 0;

      // Get existing group members
      final existingContacts =
          await LocalDataService().getGroupContacts(selectedGroup.id);
      final existingIds = existingContacts.map((c) => c.id).toSet();

      for (final contactId in selectedContactIds) {
        try {
          // Skip if already in group
          if (existingIds.contains(contactId)) {
            skipped++;
            continue;
          }

          // Add member using Supabase
          final tenantId = TenantService().tenantId;
          const uuid = Uuid();
          await Supabase.instance.client
              .schema('sms_gateway')
              .from('group_members')
              .insert({
            'id': uuid.v4(),
            'group_id': selectedGroup.id,
            'contact_id': contactId,
            'tenant_id': tenantId,
            'added_at': DateTime.now().toIso8601String(),
          });
          added++;
        } catch (e) {
          errors++;
          debugPrint('Error adding contact $contactId to group: $e');
        }
      }

      // Close progress dialog
      if (mounted) Navigator.pop(context);

      // Exit selection mode
      setState(() {
        isSelectionMode = false;
        selectedContactIds.clear();
      });

      // Show result
      if (mounted) {
        String message;
        Color backgroundColor;

        if (errors == 0 && skipped == 0) {
          message =
              '$added contact${added > 1 ? 's' : ''} added to ${selectedGroup.name}';
          backgroundColor = Colors.green;
        } else if (errors == 0) {
          message = '$added added, $skipped already in group';
          backgroundColor = Colors.blue;
        } else {
          message = '$added added, $skipped skipped, $errors failed';
          backgroundColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
          ),
        );
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

  void _createGroup() {
    showDialog(
      context: context,
      builder: (context) => CreateGroupDialog(
        onCreate: (group) {
          _loadGroups();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _deleteGroup(String id) async {
    try {
      await LocalDataService().deleteGroup(id);
      _loadGroups();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showGroupMembers(Group group) {
    showDialog(
      context: context,
      builder: (context) => GroupMembersDialog(
        group: group,
        onUpdate: _loadGroups,
      ),
    );
  }

  /// Default country code for phone number formatting (Tanzania)
  static const String _defaultCountryCode = '+255';

  /// Format phone number to international format
  /// Converts local numbers like 0653489534 to +255653489534
  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (phone.isEmpty) return '';

    // Already has + prefix - assume it's international
    if (phone.startsWith('+')) {
      return phone;
    }

    // Starts with 00 - replace with +
    if (phone.startsWith('00')) {
      return '+${phone.substring(2)}';
    }

    // Starts with 0 - replace with country code
    if (phone.startsWith('0')) {
      return '$_defaultCountryCode${phone.substring(1)}';
    }

    // Starts with country code without + (e.g., 255...)
    if (phone.startsWith('255') && phone.length >= 12) {
      return '+$phone';
    }

    // Otherwise, assume local and add country code
    return '$_defaultCountryCode$phone';
  }

  /// Import contacts from a CSV file (Enhanced with csv_import_service)
  void _importCsvContacts() async {
    try {
      // Pick CSV file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      if (file.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file')),
          );
        }
        return;
      }

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Reading and validating file...'),
            ],
          ),
        ),
      );

      // Parse CSV using new service
      final csvFile = File(file.path!);
      final csvData = await CsvImportService.parseCsvFile(csvFile);

      if (csvData.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file is empty')),
          );
        }
        return;
      }

      // Get headers and auto-detect column mapping
      final headers = CsvImportService.getHeaders(csvData);
      final autoMapping = CsvImportService.autoDetectMapping(headers);

      // Show column mapping dialog if no auto-detection
      Map<String, int>? columnMapping = autoMapping;

      if (autoMapping['phone'] == null) {
        // Need manual mapping - show dialog
        if (mounted) Navigator.pop(context);
        columnMapping = await _showColumnMappingDialog(headers);
        if (columnMapping == null || columnMapping['phone'] == null) {
          return; // User cancelled or didn't map phone
        }
        // Show loading again
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Validating contacts...'),
              ],
            ),
          ),
        );
      }

      // Initialize tenant service
      final tenantService = TenantService();
      await tenantService.initialize();
      final tenantId = tenantService.currentTenant?.id;

      if (tenantId == null) {
        if (mounted) Navigator.pop(context);
        throw Exception('No tenant selected');
      }

      // Map and validate using PhoneValidator
      final importResults = await CsvImportService.mapAndValidate(
        csvData: csvData,
        columnMapping: columnMapping,
        tenantId: tenantId,
      );

      // Load existing contacts for duplicate detection
      final existingContacts = await LocalDataService().getContacts();

      // Detect duplicates
      final duplicates = await CsvImportService.detectDuplicates(
        importResults: importResults,
        existingContacts: existingContacts,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Get summary
      final summary = CsvImportService.getSummary(importResults);

      if (summary.valid == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('No valid contacts found. ${summary.errors} errors.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show enhanced import confirmation with validation results
      if (mounted) {
        _showEnhancedImportConfirmation(
          importResults,
          duplicates,
          summary,
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  /// Show column mapping dialog for manual selection
  Future<Map<String, int>?> _showColumnMappingDialog(
      List<String> headers) async {
    int? phoneIndex;
    int? firstNameIndex;
    int? lastNameIndex;

    return showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Map CSV Columns'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select which columns contain contact information:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Phone Number (Required)
                const Text('Phone Number *',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: phoneIndex,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: headers.asMap().entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => phoneIndex = value),
                ),
                const SizedBox(height: 16),

                // First Name (Optional)
                const Text('First Name (optional)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: firstNameIndex,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('(Skip)')),
                    ...headers.asMap().entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }),
                  ],
                  onChanged: (value) => setState(() => firstNameIndex = value),
                ),
                const SizedBox(height: 16),

                // Last Name (Optional)
                const Text('Last Name (optional)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: lastNameIndex,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('(Skip)')),
                    ...headers.asMap().entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }),
                  ],
                  onChanged: (value) => setState(() => lastNameIndex = value),
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
              onPressed: phoneIndex == null
                  ? null
                  : () {
                      final mapping = <String, int>{'phone': phoneIndex!};
                      if (firstNameIndex != null) {
                        mapping['firstName'] = firstNameIndex!;
                      }
                      if (lastNameIndex != null) {
                        mapping['lastName'] = lastNameIndex!;
                      }
                      Navigator.pop(context, mapping);
                    },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show enhanced import confirmation with validation results
  void _showEnhancedImportConfirmation(
    List<ImportContactResult> importResults,
    Set<String> duplicates,
    ImportSummary summary,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Summary Card
              Card(
                margin: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.table_chart,
                              color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Import from CSV',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  '${summary.total} contacts processed',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                              'Valid', summary.valid, Colors.green),
                          _buildStatColumn(
                              'Errors', summary.errors, Colors.red),
                          _buildStatColumn(
                              'Warnings', summary.warnings, Colors.orange),
                          _buildStatColumn(
                              'Duplicates', duplicates.length, Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: summary.successRate / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(Colors.green),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.successRate.toStringAsFixed(1)}% success rate',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              // Duplicates warning
              if (duplicates.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${duplicates.length} contacts already exist and will be skipped',
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
              const Divider(),

              // Results list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: importResults.length,
                  itemBuilder: (context, index) {
                    final result = importResults[index];
                    final isDuplicate =
                        duplicates.contains(result.phoneNormalized);

                    IconData icon;
                    Color color;

                    if (!result.isValid) {
                      icon = Icons.error;
                      color = Colors.red;
                    } else if (isDuplicate) {
                      icon = Icons.content_copy;
                      color = Colors.blue;
                    } else if (result.hasWarning) {
                      icon = Icons.warning_amber;
                      color = Colors.orange;
                    } else {
                      icon = Icons.check_circle;
                      color = Colors.green;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(icon, color: color, size: 20),
                        title: Text(result.displayName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(result.phoneNormalized ??
                                result.phoneRaw ??
                                ''),
                            if (result.error != null)
                              Text(
                                result.error!,
                                style: TextStyle(color: color, fontSize: 11),
                              ),
                            if (isDuplicate && result.error == null)
                              const Text(
                                'Already exists (will be skipped)',
                                style:
                                    TextStyle(color: Colors.blue, fontSize: 11),
                              ),
                          ],
                        ),
                        trailing: Text(
                          'Row ${result.rowNumber}',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Action buttons
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: summary.valid > 0
                              ? () {
                                  Navigator.pop(context);
                                  _executeEnhancedImport(
                                      importResults, duplicates);
                                }
                              : null,
                          icon: const Icon(Icons.download),
                          label: Text(
                              'Import ${summary.valid - duplicates.length} Contacts'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  /// Execute enhanced import with proper Contact model
  void _executeEnhancedImport(
    List<ImportContactResult> importResults,
    Set<String> duplicates,
  ) async {
    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Importing contacts...'),
          ],
        ),
      ),
    );

    try {
      int imported = 0;
      int skipped = 0;
      int errors = 0;
      List<String> errorMessages = [];

      // Filter out invalid and duplicate contacts
      final validResults = importResults
          .where((r) =>
              r.isValid &&
              !duplicates.contains(r.phoneNormalized) &&
              r.contact != null)
          .toList();

      for (int i = 0; i < validResults.length; i++) {
        final result = validResults[i];
        final contact = result.contact!;

        try {
          // Use the full name or combine first/last names
          final name = contact.fullName.isNotEmpty
              ? contact.fullName
              : contact.phoneNumber;

          await LocalDataService().addContact(
            name: name,
            phoneNumber: contact.phoneNumber,
          );
          imported++;
        } catch (e) {
          if (e.toString().contains('duplicate') ||
              e.toString().contains('unique') ||
              e.toString().contains('UNIQUE')) {
            skipped++;
            errorMessages.add('Row ${result.rowNumber}: Duplicate');
          } else {
            errors++;
            errorMessages.add('Row ${result.rowNumber}: $e');
          }
        }
      }

      // Close progress dialog
      if (mounted) Navigator.pop(context);

      // Reload contacts
      _loadContacts();

      // Show result
      if (mounted) {
        _showImportResultDialog(
          imported,
          skipped + duplicates.length,
          errors,
          errorMessages,
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  /// Sync contacts from device phonebook
  void _syncPhonebook() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhonebookSyncScreen()),
    );

    // Reload contacts if sync was successful
    if (result == true) {
      _loadContacts();
    }
  }

  /// Navigate to duplicate detection screen
  void _findDuplicates() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DuplicateContactsScreen()),
    );

    // Reload contacts if duplicates were merged
    if (result == true) {
      _loadContacts();
    }
  }

  /// Import contacts from a VCF (vCard) file
  void _importVcfContacts() async {
    try {
      // Pick VCF file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vcf', 'vcard'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      if (file.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file')),
          );
        }
        return;
      }

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Reading VCF file...'),
            ],
          ),
        ),
      );

      // Read and parse VCF
      final fileContent = await File(file.path!).readAsString();
      final vcards = _parseVcf(fileContent);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (vcards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('VCF file is empty or invalid')),
          );
        }
        return;
      }

      // Parse contacts for preview with formatted phone numbers
      List<Map<String, String>> parsedContacts = [];
      List<String> warnings = [];

      for (int i = 0; i < vcards.length; i++) {
        final vcard = vcards[i];
        final name = vcard['name'] ?? '';
        final rawPhone = vcard['phone'] ?? '';
        final formattedPhone = _formatPhoneNumber(rawPhone);

        if (name.isEmpty || formattedPhone.isEmpty) {
          warnings.add('Contact ${i + 1}: Missing name or phone');
          continue;
        }

        // Validate phone (at least 10 digits for international)
        if (formattedPhone.replaceAll('+', '').length < 10) {
          warnings.add('Contact ${i + 1}: Invalid phone "$rawPhone"');
          continue;
        }

        parsedContacts.add({
          'name': name,
          'phone': formattedPhone,
          'original': rawPhone,
        });
      }

      if (parsedContacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid contacts found in file')),
          );
        }
        return;
      }

      // Show confirmation screen
      if (mounted) {
        _showImportConfirmation(parsedContacts, warnings, 'VCF');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('VCF import error: $e')),
        );
      }
    }
  }

  /// Show confirmation dialog before importing contacts
  void _showImportConfirmation(
    List<Map<String, String>> contacts,
    List<String> warnings,
    String source,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    source == 'CSV' ? Icons.table_chart : Icons.contact_phone,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import from $source',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${contacts.length} contacts ready to import',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Warnings if any
            if (warnings.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${warnings.length} contacts skipped (invalid data)',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Info about phone format
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Numbers will be converted to international format ($_defaultCountryCode)',
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            // Contact list preview
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  final showConversion =
                      contact['original'] != contact['phone'];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(contact['name']![0].toUpperCase()),
                    ),
                    title: Text(contact['name']!),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact['phone']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                        if (showConversion)
                          Text(
                            'Original: ${contact['original']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
            // Action buttons
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _executeImport(contacts);
                        },
                        icon: const Icon(Icons.download),
                        label: Text('Import ${contacts.length} Contacts'),
                      ),
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

  /// Execute the actual import after confirmation
  void _executeImport(List<Map<String, String>> contacts) async {
    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Importing contacts...'),
          ],
        ),
      ),
    );

    try {
      int imported = 0;
      int skipped = 0;
      int errors = 0;
      List<String> errorMessages = [];

      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        final name = contact['name']!;
        final phone = contact['phone']!;

        try {
          await LocalDataService().addContact(
            name: name,
            phoneNumber: phone,
          );
          imported++;
        } catch (e) {
          if (e.toString().contains('duplicate') ||
              e.toString().contains('unique') ||
              e.toString().contains('UNIQUE')) {
            skipped++;
            errorMessages.add('${i + 1}. "$name": Duplicate');
          } else {
            errors++;
            errorMessages.add('${i + 1}. "$name": $e');
          }
        }
      }

      // Close progress dialog
      if (mounted) Navigator.pop(context);

      // Reload contacts
      _loadContacts();

      // Show result
      if (mounted) {
        _showImportResultDialog(imported, skipped, errors, errorMessages);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  /// Parse VCF (vCard) content into a list of contacts
  List<Map<String, String>> _parseVcf(String content) {
    final List<Map<String, String>> contacts = [];
    final lines = content.split('\n');

    String? currentName;
    String? currentPhone;
    bool inVcard = false;

    for (var line in lines) {
      line = line.trim();

      if (line.startsWith('BEGIN:VCARD')) {
        inVcard = true;
        currentName = null;
        currentPhone = null;
      } else if (line.startsWith('END:VCARD')) {
        if (inVcard && (currentName != null || currentPhone != null)) {
          contacts.add({
            'name': currentName ?? 'Unknown',
            'phone': currentPhone ?? '',
          });
        }
        inVcard = false;
      } else if (inVcard) {
        // Parse FN (Full Name) - preferred
        if (line.startsWith('FN:') || line.startsWith('FN;')) {
          currentName = _extractVcfValue(line);
        }
        // Parse N (Name) as fallback - format: Last;First;Middle;Prefix;Suffix
        else if (line.startsWith('N:') || line.startsWith('N;')) {
          if (currentName == null || currentName.isEmpty) {
            final nameParts = _extractVcfValue(line).split(';');
            if (nameParts.length >= 2) {
              final firstName = nameParts[1].trim();
              final lastName = nameParts[0].trim();
              currentName = '$firstName $lastName'.trim();
            } else if (nameParts.isNotEmpty) {
              currentName = nameParts[0].trim();
            }
          }
        }
        // Parse TEL (Phone) - prefer CELL or first available
        else if (line.startsWith('TEL')) {
          // Extract phone number
          final phone = _extractVcfValue(line);
          // Prefer cell phone, but take first if no cell
          if (line.toUpperCase().contains('CELL') ||
              line.toUpperCase().contains('MOBILE') ||
              currentPhone == null) {
            currentPhone = phone;
          }
        }
      }
    }

    return contacts;
  }

  /// Extract value from VCF line (handles various formats)
  String _extractVcfValue(String line) {
    // Handle lines like "TEL;TYPE=CELL:+255683274343" or "FN:John Doe"
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) return line;
    return line.substring(colonIndex + 1).trim();
  }

  void _showImportResultDialog(
      int imported, int skipped, int errors, List<String> errorMessages) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              imported > 0 ? Icons.check_circle : Icons.info,
              color: imported > 0 ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Import Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow(Icons.check, Colors.green, 'Imported', imported),
            _buildResultRow(Icons.skip_next, Colors.orange, 'Skipped', skipped),
            if (errors > 0)
              _buildResultRow(Icons.error, Colors.red, 'Errors', errors),
            if (errorMessages.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Details:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: errorMessages
                        .take(10)
                        .map(
                          (msg) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(msg,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              if (errorMessages.length > 10)
                Text(
                  '... and ${errorMessages.length - 10} more',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(IconData icon, Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text('$label: '),
          Text('$count',
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Add Contact'),
              subtitle: const Text('Manually enter a new contact'),
              onTap: () {
                Navigator.pop(context);
                _addContact();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Import from CSV'),
              subtitle: const Text('Import contacts from a CSV file'),
              onTap: () {
                Navigator.pop(context);
                _importCsvContacts();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts),
              title: const Text('Sync from Phonebook'),
              subtitle: const Text('Import contacts from device phonebook'),
              onTap: () {
                Navigator.pop(context);
                _syncPhonebook();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone),
              title: const Text('Import from VCF'),
              subtitle: const Text('Import contacts from vCard file'),
              onTap: () {
                Navigator.pop(context);
                _importVcfContacts();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.merge_type, color: Colors.orange),
              title: const Text('Find Duplicates'),
              subtitle: const Text('Detect and merge duplicate contacts'),
              onTap: () {
                Navigator.pop(context);
                _findDuplicates();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContactsTab(),
          _buildGroupsTab(),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? null // Hide FAB in selection mode
          : FloatingActionButton(
              onPressed: () {
                if (_tabController.index == 0) {
                  _showAddOptions(); // Show options: Add Contact or Import CSV
                } else {
                  _createGroup();
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  /// Normal AppBar with tabs
  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: const Text('Contacts & Groups'),
      elevation: 0,
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white, // Selected tab text/icon color
        unselectedLabelColor: Colors.white70, // Unselected tab color
        indicatorColor: Colors.white, // Tab indicator line color
        indicatorWeight: 3,
        tabs: const [
          Tab(icon: Icon(Icons.contacts), text: 'Contacts'),
          Tab(icon: Icon(Icons.group), text: 'Groups'),
        ],
      ),
    );
  }

  /// Selection mode AppBar with actions
  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          setState(() {
            isSelectionMode = false;
            selectedContactIds.clear();
          });
        },
      ),
      title: Text('${selectedContactIds.length} selected'),
      elevation: 0,
      actions: [
        // Add to group button
        IconButton(
          icon: const Icon(Icons.group_add),
          tooltip: 'Add to group',
          onPressed:
              selectedContactIds.isEmpty ? null : _addSelectedContactsToGroup,
        ),
        // Select all button
        IconButton(
          icon: Icon(
            selectedContactIds.length == filteredContacts.length
                ? Icons.deselect
                : Icons.select_all,
          ),
          tooltip: selectedContactIds.length == filteredContacts.length
              ? 'Deselect all'
              : 'Select all',
          onPressed: _selectAllContacts,
        ),
        // Delete button
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete selected',
          onPressed:
              selectedContactIds.isEmpty ? null : _deleteSelectedContacts,
        ),
      ],
    );
  }

  Widget _buildContactsTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (contacts.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.contacts_outlined,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'No Contacts Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              const Text(
                'Start building your contact list to send SMS',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Primary action - Add Contact
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addContact,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Contact Manually'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary action - Import CSV
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _importCsvContacts,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import from CSV'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tertiary action - Import VCF
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _importVcfContacts,
                  icon: const Icon(Icons.contact_phone),
                  label: const Text('Import from VCF/vCard'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Info section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      icon: Icons.person_add,
                      text:
                          'Add contacts one by one with name and phone number',
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem(
                      icon: Icons.upload_file,
                      text: 'Import bulk contacts from CSV or VCF/vCard files',
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem(
                      icon: Icons.group,
                      text:
                          'Organize contacts into groups for easier management',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: TextField(
            controller: _searchController,
            onChanged: _filterContacts,
            decoration: InputDecoration(
              hintText: 'Search contacts by name or number',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterContacts('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
        ),
        // Contact list
        Expanded(
          child: filteredContacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No contacts found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your search',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = filteredContacts[index];
                    final isSelected = selectedContactIds.contains(contact.id);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppTheme.paddingMedium,
                        vertical: AppTheme.paddingSmall,
                      ),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        leading: isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) =>
                                    _toggleContactSelection(contact.id),
                              )
                            : CircleAvatar(
                                child: Text(contact.name[0].toUpperCase()),
                              ),
                        title: Text(contact.name),
                        subtitle: Text(contact.phoneNumber),
                        trailing: isSelectionMode
                            ? null
                            : IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteContact(contact.id),
                              ),
                        onTap: isSelectionMode
                            ? () => _toggleContactSelection(contact.id)
                            : null,
                        onLongPress: isSelectionMode
                            ? null
                            : () {
                                // Enter selection mode on long press
                                setState(() {
                                  isSelectionMode = true;
                                  selectedContactIds.add(contact.id);
                                });
                              },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final tipColor = color ?? Colors.blue;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: tipColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: tipColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (groups.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_outlined,
                  size: 60,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'No Groups Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              const Text(
                'Create groups to organize your contacts',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Primary action - Create Group
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createGroup,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Create Group'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Info section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Benefits of Groups',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      icon: Icons.folder,
                      text:
                          'Organize contacts by category (Family, Work, Clients)',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem(
                      icon: Icons.send,
                      text: 'Send bulk SMS to entire groups at once',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem(
                      icon: Icons.speed,
                      text: 'Save time with quick group selection',
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingMedium,
            vertical: AppTheme.paddingSmall,
          ),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(group.name[0].toUpperCase()),
            ),
            title: Text(group.name),
            subtitle: Text('${group.memberCount ?? 0} members'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteGroup(group.id),
            ),
            onTap: () => _showGroupMembers(group),
          ),
        );
      },
    );
  }
}

// Add Contact Dialog
class AddContactDialog extends StatefulWidget {
  final Function(Contact) onAdd;

  const AddContactDialog({required this.onAdd, super.key});

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  bool isLoading = false;
  String? formattedPhone;

  /// Default country code for phone number formatting (Tanzania)
  static const String _defaultCountryCode = '+255';

  /// Format phone number to international format
  String _formatPhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) return '';
    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('00')) return '+${phone.substring(2)}';
    if (phone.startsWith('0')) {
      return '$_defaultCountryCode${phone.substring(1)}';
    }
    if (phone.startsWith('255') && phone.length >= 12) return '+$phone';
    return '$_defaultCountryCode$phone';
  }

  void _updateFormattedPhone() {
    final raw = phoneController.text.trim();
    if (raw.isNotEmpty) {
      setState(() {
        formattedPhone = _formatPhoneNumber(raw);
      });
    } else {
      setState(() {
        formattedPhone = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    phoneController.addListener(_updateFormattedPhone);
  }

  void _save() async {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final phone = _formatPhoneNumber(phoneController.text.trim());

    // Validate phone (at least 10 digits for international)
    if (phone.replaceAll('+', '').length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone number')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final contact = await LocalDataService().addContact(
        name: nameController.text,
        phoneNumber: phone,
      );

      if (mounted) {
        widget.onAdd(contact);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Contact'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'John Doe',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phoneController,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '0653489534',
              helperText: formattedPhone != null
                  ? 'Will be saved as: $formattedPhone'
                  : 'Numbers will be formatted to international format',
              helperStyle: TextStyle(
                color: formattedPhone != null ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _save,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}

// Create Group Dialog
class CreateGroupDialog extends StatefulWidget {
  final Function(Group) onCreate;

  const CreateGroupDialog({required this.onCreate, super.key});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final nameController = TextEditingController();
  List<Contact> selectedContacts = [];
  List<Contact> availableContacts = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableContacts();
  }

  void _loadAvailableContacts() async {
    try {
      final contacts = await LocalDataService().getContacts();

      if (mounted) {
        setState(() {
          availableContacts = contacts;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  void _save() async {
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter group name')),
      );
      return;
    }

    if (selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final group = await LocalDataService().createGroup(
        name: nameController.text,
        contactIds: selectedContacts.map((c) => c.id).toList(),
      );

      if (mounted) {
        widget.onCreate(group);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create Group',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g., Work Team',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Members (${selectedContacts.length} selected)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isLoading ? null : _save,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }
}

// Group Members Dialog
class GroupMembersDialog extends StatefulWidget {
  final Group group;
  final VoidCallback onUpdate;

  const GroupMembersDialog({
    required this.group,
    required this.onUpdate,
    super.key,
  });

  @override
  State<GroupMembersDialog> createState() => _GroupMembersDialogState();
}

class _GroupMembersDialogState extends State<GroupMembersDialog> {
  List<Contact> members = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() async {
    try {
      final contacts =
          await LocalDataService().getGroupContacts(widget.group.id);

      if (mounted) {
        setState(() {
          members = contacts;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.group.name} Members'),
      content: isLoading
          ? const SizedBox(
              width: 300,
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 300,
              height: 300,
              child: members.isEmpty
                  ? const Center(child: Text('No members'))
                  : ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return ListTile(
                          title: Text(member.name),
                          subtitle: Text(member.phoneNumber),
                        );
                      },
                    ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
