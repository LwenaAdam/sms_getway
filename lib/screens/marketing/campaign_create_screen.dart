import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/marketing_campaign.dart';
import '../../contacts/contact_model.dart';
import '../../groups/group_model.dart';
import '../../core/tenant_service.dart';

/// Campaign Create/Edit Screen
/// Create new marketing campaign or edit existing one
class CampaignCreateScreen extends StatefulWidget {
  final MarketingCampaign? campaign;

  const CampaignCreateScreen({super.key, this.campaign});

  @override
  State<CampaignCreateScreen> createState() => _CampaignCreateScreenState();
}

class _CampaignCreateScreenState extends State<CampaignCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _tenantService = TenantService();

  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();

  List<Contact> _availableContacts = [];
  List<Group> _availableGroups = [];
  final Set<String> _selectedContactIds = {};
  final Set<String> _selectedGroupIds = {};
  bool _loading = false;
  bool _loadingContacts = false;
  bool _loadingGroups = false;
  String _searchQuery = '';
  int _loadedContactCount = 0;
  int _totalContactCount = 0;

  bool get _isEditing => widget.campaign != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.campaign!.name;
      _messageController.text = widget.campaign!.messageTemplate;
    }
    _loadContacts();
    _loadGroups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _loadingContacts = true);

    try {
      await _tenantService.initialize();
      final tenantId = _tenantService.currentTenant?.id;
      if (tenantId == null) throw Exception('No tenant selected');

      // Load all contacts with high limit (Supabase default is 1000)
      // Set to 100,000 to handle large contact lists
      final response = await _supabase
          .schema('sms_gateway')
          .from('contacts')
          .select()
          .eq('tenant_id', tenantId)
          .order('name')
          .limit(100000); // Explicit high limit to override default 1000

      final contacts =
          (response as List).map((json) => Contact.fromJson(json)).toList();

      setState(() {
        _availableContacts = contacts;
        _loadedContactCount = contacts.length;
        _totalContactCount = contacts.length;
        _loadingContacts = false;
      });
    } catch (e) {
      setState(() => _loadingContacts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading contacts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);

    try {
      await _tenantService.initialize();
      final tenantId = _tenantService.currentTenant?.id;
      if (tenantId == null) throw Exception('No tenant selected');

      final response =
          await _supabase.schema('sms_gateway').from('groups').select('''
            id,
            name,
            user_id,
            tenant_id,
            created_at
          ''').eq('tenant_id', tenantId).order('name');

      final groups =
          (response as List).map((json) => Group.fromJson(json)).toList();

      setState(() {
        _availableGroups = groups;
        _loadingGroups = false;
      });
    } catch (e) {
      setState(() => _loadingGroups = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading groups: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectGroup(String groupId) async {
    try {
      // Load all contacts in this group
      final response = await _supabase
          .schema('sms_gateway')
          .from('group_members')
          .select('contact_id')
          .eq('group_id', groupId);

      final contactIds = (response as List)
          .map((json) => json['contact_id'] as String)
          .toSet();

      setState(() {
        if (_selectedGroupIds.contains(groupId)) {
          // Deselect group - remove its contacts
          _selectedGroupIds.remove(groupId);
          _selectedContactIds.removeAll(contactIds);
        } else {
          // Select group - add its contacts
          _selectedGroupIds.add(groupId);
          _selectedContactIds.addAll(contactIds);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting group: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _availableContacts;

    final query = _searchQuery.toLowerCase();
    return _availableContacts.where((contact) {
      return contact.name.toLowerCase().contains(query) ||
          contact.phoneNumber.toLowerCase().contains(query) ||
          (contact.firstName?.toLowerCase().contains(query) ?? false) ||
          (contact.lastName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  String _renderPreview() {
    String message = _messageController.text;

    // Use first selected contact for preview, or sample data
    Contact? sampleContact;
    if (_selectedContactIds.isNotEmpty) {
      sampleContact = _availableContacts.firstWhere(
        (c) => _selectedContactIds.contains(c.id),
        orElse: () => _availableContacts.first,
      );
    }

    final firstName = sampleContact?.firstName ?? 'John';
    final lastName = sampleContact?.lastName ?? 'Doe';
    final phone = sampleContact?.phoneNumber ?? '+255712345678';

    message = message.replaceAll('{first_name}', firstName);
    message = message.replaceAll('{last_name}', lastName);
    message = message.replaceAll('{phone}', phone);

    return message;
  }

  Future<void> _saveCampaign({bool activate = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one contact'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _tenantService.initialize();
      final tenantId = _tenantService.currentTenant?.id;
      if (tenantId == null) throw Exception('No tenant selected');

      final userId = _supabase.auth.currentUser?.id;

      String campaignId;

      if (_isEditing) {
        // Update existing campaign
        await _supabase
            .schema('sms_gateway')
            .from('marketing_campaigns')
            .update({
          'name': _nameController.text.trim(),
          'message_template': _messageController.text.trim(),
          if (activate) ...{
            'status': 'active',
            'activated_at': DateTime.now().toIso8601String(),
          },
        }).eq('id', widget.campaign!.id);

        campaignId = widget.campaign!.id;
      } else {
        // Create new campaign
        final response = await _supabase
            .schema('sms_gateway')
            .from('marketing_campaigns')
            .insert({
              'tenant_id': tenantId,
              'name': _nameController.text.trim(),
              'message_template': _messageController.text.trim(),
              'status': activate ? 'active' : 'draft',
              'total_contact_count': _selectedContactIds.length,
              'created_by': userId,
              if (activate) 'activated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        campaignId = response['id'] as String;

        // Add selected contacts to campaign
        // Filter contacts with valid phone numbers only
        final contactsToAdd = _availableContacts
            .where((c) => _selectedContactIds.contains(c.id))
            .where((c) {
          // Clean and validate phone number to match DB constraint: ^\+?[1-9]\d{1,14}$
          final phone = c.phoneNumber.trim();
          // Remove spaces, dashes, parentheses
          final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
          // Match database constraint: optional +, starts with 1-9, followed by 1-14 digits
          return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(cleanPhone);
        }).map((c) {
          // Clean phone number for database
          final cleanPhone =
              c.phoneNumber.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
          return {
            'campaign_id': campaignId,
            'contact_id': c.id,
            'phone_number': cleanPhone,
            'first_name': c.firstName,
            'last_name': c.lastName,
            'status': 'pending',
          };
        }).toList();

        final skippedCount = _selectedContactIds.length - contactsToAdd.length;

        if (contactsToAdd.isNotEmpty) {
          await _supabase
              .schema('sms_gateway')
              .from('marketing_campaign_contacts')
              .insert(contactsToAdd);
        }

        // Show warning if some contacts were skipped
        if (skippedCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ $skippedCount contact(s) skipped due to invalid phone numbers',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activate
                  ? '✅ Campaign activated!'
                  : _isEditing
                      ? '✅ Campaign updated'
                      : '✅ Campaign created',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
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
        title: Text(_isEditing ? 'Edit Campaign' : 'New Campaign'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Campaign Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Campaign Name',
                hintText: 'e.g., Spring Sale 2026',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.campaign),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a campaign name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Message Template
            Text(
              'Message Template',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Hi {first_name}, check out our new offers!',
                border: OutlineInputBorder(),
                helperText:
                    'Use {first_name}, {last_name}, {phone} for personalization',
              ),
              maxLines: 4,
              maxLength: 160,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a message';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Preview Card
            if (_messageController.text.isNotEmpty) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.preview, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Preview',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_renderPreview()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Contact Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Recipients',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_selectedContactIds.length ==
                          _availableContacts.length) {
                        _selectedContactIds.clear();
                        _selectedGroupIds.clear();
                      } else {
                        _selectedContactIds
                          ..clear()
                          ..addAll(_availableContacts.map((c) => c.id));
                        // Don't auto-select groups when selecting all contacts
                      }
                    });
                  },
                  icon: Icon(
                    _selectedContactIds.length == _availableContacts.length
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 18,
                  ),
                  label: Text(
                    _selectedContactIds.length == _availableContacts.length
                        ? 'Deselect All'
                        : 'Select All',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Groups Section
            if (_loadingGroups)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_availableGroups.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.group_work, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Select Groups',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableGroups.map((group) {
                          final isSelected =
                              _selectedGroupIds.contains(group.id);
                          return FilterChip(
                            label: Text(group.name),
                            selected: isSelected,
                            onSelected: (_) => _selectGroup(group.id),
                            avatar: Icon(
                              isSelected ? Icons.check_circle : Icons.group,
                              size: 16,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Search Bar
            if (_availableContacts.isNotEmpty)
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            const SizedBox(height: 12),

            if (_loadingContacts)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading contacts...'),
                    ],
                  ),
                ),
              )
            else if (_availableContacts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.contacts_outlined, size: 48),
                      const SizedBox(height: 8),
                      const Text('No contacts available'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to contacts screen
                        },
                        child: const Text('Add Contacts'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.group, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedContactIds.length} selected',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          if (_totalContactCount > 0)
                            Text(
                              '$_loadedContactCount / $_totalContactCount loaded',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (_filteredContacts.isEmpty && _searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'No contacts found for "$_searchQuery"',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = _filteredContacts[index];
                            final isSelected =
                                _selectedContactIds.contains(contact.id);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedContactIds.add(contact.id);
                                  } else {
                                    _selectedContactIds.remove(contact.id);
                                  }
                                });
                              },
                              title: Text(contact.fullName),
                              subtitle: Text(contact.phoneNumber),
                              secondary: CircleAvatar(
                                child: Text(
                                  contact.firstName
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      contact.name
                                          .substring(0, 1)
                                          .toUpperCase(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _loading ? null : () => _saveCampaign(activate: false),
                    child: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save as Draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _loading ? null : () => _saveCampaign(activate: true),
                    child: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save & Activate'),
                  ),
                ),
              ],
            ),

            // Info Cards
            const SizedBox(height: 16),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing all ${_totalContactCount > 0 ? _totalContactCount : _loadedContactCount} contacts. Use groups for quick selection.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_outlined,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Daily limit: 100 SMS/day. Each contact receives max 2 SMS per 30 days.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
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
}
