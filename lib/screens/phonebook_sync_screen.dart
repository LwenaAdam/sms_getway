import 'package:flutter/material.dart';
import '../services/phonebook_sync_service.dart';
import '../services/local_data_service.dart';
import '../core/tenant_service.dart';
import '../core/theme.dart';

/// Phonebook Sync Screen
///
/// Allows users to sync contacts from device phonebook
class PhonebookSyncScreen extends StatefulWidget {
  const PhonebookSyncScreen({super.key});

  @override
  State<PhonebookSyncScreen> createState() => _PhonebookSyncScreenState();
}

class _PhonebookSyncScreenState extends State<PhonebookSyncScreen> {
  final _tenantService = TenantService();

  // Sync flow state
  SyncStep _currentStep = SyncStep.checkPermission;
  List<PhonebookContactResult> _phonebookResults = [];
  Set<String> _selectedIndices = {};
  Set<String> _duplicates = {};
  bool _skipDuplicates = true;

  // UI state
  bool _loading = false;
  String? _error;
  int _syncedCount = 0;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync from Phonebook'),
        actions: [
          if (_currentStep != SyncStep.checkPermission &&
              _currentStep != SyncStep.complete)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Start Over'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildStepContent(),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case SyncStep.checkPermission:
        return _buildPermissionStep();
      case SyncStep.loadContacts:
        return _buildLoadingStep();
      case SyncStep.selectContacts:
        return _buildSelectContactsStep();
      case SyncStep.syncing:
        return _buildSyncingStep();
      case SyncStep.complete:
        return _buildCompleteStep();
    }
  }

  // Step 1: Permission Check
  Widget _buildPermissionStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 24),
          Text(
            'Access Device Contacts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'We need permission to read your device contacts to import them',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _requestPermission,
            icon: const Icon(Icons.security),
            label: const Text('Grant Permission'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // Step 2: Loading
  Widget _buildLoadingStep() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Loading contacts from phonebook...'),
        ],
      ),
    );
  }

  // Step 3: Select Contacts
  Widget _buildSelectContactsStep() {
    final validResults = _phonebookResults.where((r) => r.isValid).toList();
    final errorResults = _phonebookResults.where((r) => r.hasError).toList();
    final summary =
        PhonebookSyncService.getSummary(_phonebookResults, _duplicates);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Summary Card
        Card(
          margin: const EdgeInsets.all(16),
          color: isDark ? const Color(0xFF1E2836) : Colors.blue.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? const Color(0xFF2C3E50) : Colors.blue.shade100,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.contact_phone,
                        color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Device Contacts',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${summary.total} contacts found',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Valid', summary.valid, Colors.green),
                    _buildStatColumn('Errors', summary.errors, Colors.red),
                    _buildStatColumn(
                        'Duplicates', summary.duplicates, Colors.blue),
                    _buildStatColumn(
                        'Selected', _selectedIndices.length, Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Selection Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Checkbox(
                value: _selectAll,
                onChanged: (value) {
                  setState(() {
                    _selectAll = value ?? false;
                    if (_selectAll) {
                      _selectedIndices = validResults
                          .where(
                              (r) => !_duplicates.contains(r.normalizedPhone))
                          .map((r) => r.index.toString())
                          .toSet();
                    } else {
                      _selectedIndices.clear();
                    }
                  });
                },
              ),
              const Text('Select All'),
              const Spacer(),
              if (_duplicates.isNotEmpty) ...[
                const Text('Skip duplicates', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _skipDuplicates,
                  onChanged: (value) {
                    setState(() => _skipDuplicates = value);
                  },
                ),
              ],
            ],
          ),
        ),

        // Error Summary
        if (errorResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${errorResults.length} contacts have invalid phone numbers',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Contacts List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _phonebookResults.length,
            itemBuilder: (context, index) {
              final result = _phonebookResults[index];
              final isDuplicate = _duplicates.contains(result.normalizedPhone);
              final isSelected =
                  _selectedIndices.contains(result.index.toString());

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: result.isValid && !isDuplicate
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedIndices.add(result.index.toString());
                              } else {
                                _selectedIndices
                                    .remove(result.index.toString());
                              }
                              _selectAll = _selectedIndices.length ==
                                  validResults
                                      .where((r) => !_duplicates
                                          .contains(r.normalizedPhone))
                                      .length;
                            });
                          },
                        )
                      : Icon(
                          result.hasError ? Icons.error : Icons.content_copy,
                          color: result.hasError ? Colors.red : Colors.blue,
                          size: 20,
                        ),
                  title: Text(result.displayName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          result.normalizedPhone ?? result.contact.phoneNumber),
                      if (result.error != null)
                        Text(
                          result.error!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 11),
                        ),
                      if (isDuplicate)
                        const Text(
                          'Already exists',
                          style: TextStyle(color: Colors.blue, fontSize: 11),
                        ),
                    ],
                  ),
                  trailing: Text(
                    '#${result.index}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              );
            },
          ),
        ),

        // Action Buttons
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
                    onPressed: _selectedIndices.isEmpty ? null : _syncContacts,
                    icon: const Icon(Icons.sync),
                    label: Text('Sync ${_selectedIndices.length} Contacts'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Step 4: Syncing
  Widget _buildSyncingStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Syncing contacts...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('$_syncedCount contacts synced'),
        ],
      ),
    );
  }

  // Step 5: Complete
  Widget _buildCompleteStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'Sync Complete!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('$_syncedCount contacts synced successfully'),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _reset,
            child: const Text('Sync More Contacts'),
          ),
        ],
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

  // Actions
  Future<void> _checkPermission() async {
    setState(() => _loading = true);

    try {
      final hasPermission = await PhonebookSyncService.hasPermission();

      setState(() {
        _loading = false;
        if (hasPermission) {
          _currentStep = SyncStep.loadContacts;
          _loadContacts();
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to check permission: $e';
      });
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final granted = await PhonebookSyncService.requestPermission();

      if (granted) {
        // Check if actually granted
        final hasPermission = await PhonebookSyncService.hasPermission();

        if (hasPermission) {
          setState(() => _currentStep = SyncStep.loadContacts);
          await _loadContacts();
        } else {
          setState(() {
            _loading = false;
            _error =
                'Permission denied. Please grant contacts permission in settings.';
          });
        }
      } else {
        setState(() {
          _loading = false;
          _error = 'Permission denied';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to request permission: $e';
      });
    }
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);

    try {
      // Load phonebook contacts
      final phonebookContacts =
          await PhonebookSyncService.getPhonebookContacts();

      if (phonebookContacts.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No contacts found in phonebook';
        });
        return;
      }

      // Validate contacts
      final results =
          await PhonebookSyncService.validateContacts(phonebookContacts);

      // Load existing contacts for duplicate detection
      final existingContacts = await LocalDataService().getContacts();

      // Detect duplicates
      final duplicates = PhonebookSyncService.detectDuplicates(
        phonebookResults: results,
        existingContacts: existingContacts,
      );

      setState(() {
        _phonebookResults = results;
        _duplicates = duplicates;
        _currentStep = SyncStep.selectContacts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load contacts: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _syncContacts() async {
    setState(() {
      _currentStep = SyncStep.syncing;
      _syncedCount = 0;
    });

    try {
      await _tenantService.initialize();
      final tenantId = _tenantService.currentTenant?.id;

      if (tenantId == null) throw Exception('No tenant selected');

      // Filter selected and valid contacts
      final selectedResults = _phonebookResults.where((r) {
        return _selectedIndices.contains(r.index.toString()) &&
            r.isValid &&
            (_skipDuplicates ? !_duplicates.contains(r.normalizedPhone) : true);
      }).toList();

      // Convert to Contact models
      final contacts = PhonebookSyncService.toContactModels(
        results: selectedResults,
        tenantId: tenantId,
      );

      // Import in batches of 50
      const batchSize = 50;
      for (int i = 0; i < contacts.length; i += batchSize) {
        final batch = contacts.skip(i).take(batchSize).toList();

        for (final contact in batch) {
          try {
            await LocalDataService().addContact(
              name: contact.name,
              phoneNumber: contact.phoneNumber,
            );
            setState(() => _syncedCount++);
          } catch (e) {
            // Skip duplicates silently
            if (!e.toString().contains('duplicate') &&
                !e.toString().contains('unique') &&
                !e.toString().contains('UNIQUE')) {
              rethrow;
            }
          }
        }
      }

      setState(() => _currentStep = SyncStep.complete);
    } catch (e) {
      setState(() {
        _currentStep = SyncStep.selectContacts;
        _error = 'Sync failed: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _currentStep = SyncStep.checkPermission;
      _phonebookResults.clear();
      _selectedIndices.clear();
      _duplicates.clear();
      _error = null;
      _syncedCount = 0;
      _selectAll = false;
    });
    _checkPermission();
  }
}

enum SyncStep {
  checkPermission,
  loadContacts,
  selectContacts,
  syncing,
  complete,
}
