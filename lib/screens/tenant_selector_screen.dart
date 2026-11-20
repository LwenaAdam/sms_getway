/// Tenant Selector Screen - Let users choose which workspace to use
/// Shown only if user has 2+ tenants
library;

import 'package:flutter/material.dart';
import '../core/tenant_service.dart';
import '../core/theme.dart';
import '../main.dart';

class TenantSelectorScreen extends StatefulWidget {
  final List<TenantModel> tenants;
  final VoidCallback? onTenantSelected;

  const TenantSelectorScreen({
    super.key,
    required this.tenants,
    this.onTenantSelected,
  });

  @override
  State<TenantSelectorScreen> createState() => _TenantSelectorScreenState();
}

class _TenantSelectorScreenState extends State<TenantSelectorScreen> {
  final TenantService _tenantService = TenantService();
  TenantModel? _selectedTenant;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-select first tenant
    _selectedTenant = widget.tenants.isNotEmpty ? widget.tenants[0] : null;
  }

  Future<void> _selectTenant(TenantModel tenant) async {
    setState(() {
      _selectedTenant = tenant;
    });
  }

  Future<void> _confirmSelection() async {
    if (_selectedTenant == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _tenantService.selectTenant(_selectedTenant!);

      if (!mounted) return;

      // Navigate to HomePage directly
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting workspace: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getRoleDisplay(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'member':
        return 'Member';
      case 'viewer':
        return 'Viewer';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'member':
        return Colors.green;
      case 'viewer':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Workspace'),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingLarge),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.business,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Choose Your Workspace',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You have access to ${widget.tenants.length} organization(s)',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tenant List
                Text(
                  'Available Organizations',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.tenants.length,
                  itemBuilder: (context, index) {
                    final tenant = widget.tenants[index];
                    final isSelected = _selectedTenant?.id == tenant.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: _isLoading ? null : () => _selectTenant(tenant),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : (isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                : (isDark ? Colors.grey[850] : Colors.white),
                          ),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    tenant.name.isNotEmpty
                                        ? tenant.name[0].toUpperCase()
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

                              // Tenant Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tenant.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(tenant.role)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _getRoleDisplay(tenant.role),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getRoleColor(tenant.role),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Selection Indicator
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primaryColor,
                                  size: 24,
                                )
                              else
                                Icon(
                                  Icons.circle_outlined,
                                  color: isDark
                                      ? Colors.grey[600]
                                      : Colors.grey[400],
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading || _selectedTenant == null
                        ? null
                        : _confirmSelection,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _selectedTenant != null
                                ? 'Continue to ${_selectedTenant!.name}'
                                : 'Select a Workspace',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
