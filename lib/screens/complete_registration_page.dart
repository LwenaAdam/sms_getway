import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

/// Complete Registration Flow with Organization Setup
///
/// This page handles:
/// 1. User authentication (auth.users)
/// 2. Client creation (public.clients)
/// 3. Tenant creation (sms_gateway.tenants)
/// 4. User profile creation (sms_gateway.users)
/// 5. Tenant membership (sms_gateway.tenant_members)
/// 6. User settings initialization (sms_gateway.user_settings)
/// 7. Tenant settings initialization (sms_gateway.tenant_settings)
/// 8. Product access record (public.client_product_access) - Required for login
class CompleteRegistrationPage extends StatefulWidget {
  const CompleteRegistrationPage({super.key});

  @override
  State<CompleteRegistrationPage> createState() =>
      _CompleteRegistrationPageState();
}

class _CompleteRegistrationPageState extends State<CompleteRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Step 1: Account Details
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();

  // Step 2: Organization Details
  final orgNameController = TextEditingController();
  final orgSubdomainController = TextEditingController();
  String selectedPlan = 'basic';

  bool isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    orgNameController.dispose();
    orgSubdomainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Registration'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProgressIndicator(),
                const SizedBox(height: AppTheme.paddingLarge),
                if (_currentStep == 0) _buildAccountStep(),
                if (_currentStep == 1) _buildOrganizationStep(),
                if (_currentStep == 2) _buildConfirmationStep(),
                const SizedBox(height: AppTheme.paddingLarge),
                if (errorMessage != null) _buildErrorMessage(),
                const SizedBox(height: AppTheme.paddingLarge),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(0, 'Account'),
        _buildStepLine(0),
        _buildStepCircle(1, 'Organization'),
        _buildStepLine(1),
        _buildStepCircle(2, 'Confirm'),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted
                ? AppTheme.primaryColor
                : Colors.grey[300],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppTheme.primaryColor : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isCompleted = step < _currentStep;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isCompleted ? AppTheme.primaryColor : Colors.grey[300],
    );
  }

  // STEP 1: Account Details
  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Your Account',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your personal details to get started',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: AppTheme.paddingLarge),
        TextFormField(
          controller: fullNameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person),
            hintText: 'John Doe',
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.email),
            hintText: 'john@example.com',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email is required';
            if (!v.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            prefixIcon: Icon(Icons.phone),
            hintText: '+255712345678',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Phone is required';
            if (v.length < 10) return 'Enter a valid phone number';
            return null;
          },
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        TextFormField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock),
            hintText: 'Minimum 8 characters',
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
            if (v.length < 8) return 'Use at least 8 characters';
            return null;
          },
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        TextFormField(
          controller: confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please confirm password';
            if (v != passwordController.text) return 'Passwords do not match';
            return null;
          },
        ),
      ],
    );
  }

  // STEP 2: Organization Details
  Widget _buildOrganizationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Setup Your Organization',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Create an organization to manage your SMS Gateway',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: AppTheme.paddingLarge),
        TextFormField(
          controller: orgNameController,
          decoration: const InputDecoration(
            labelText: 'Organization Name',
            prefixIcon: Icon(Icons.business),
            hintText: 'Acme Corp',
          ),
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Organization name is required'
              : null,
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        TextFormField(
          controller: orgSubdomainController,
          decoration: const InputDecoration(
            labelText: 'Subdomain',
            prefixIcon: Icon(Icons.link),
            hintText: 'acme',
            suffixText: '.smsgateway.app',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Subdomain is required';
            if (v.contains(' ')) return 'No spaces allowed';
            if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v)) {
              return 'Only lowercase letters, numbers, and hyphens';
            }
            return null;
          },
        ),
        const SizedBox(height: AppTheme.paddingLarge),
        Text(
          'Select Plan',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        _buildPlanOption(
            'basic', 'Free Plan', '100 SMS/month', Icons.star_border),
        _buildPlanOption(
            'pro', 'Starter Plan', '1,000 SMS/month', Icons.star_half),
        _buildPlanOption('enterprise', 'Pro Plan', 'Unlimited SMS', Icons.star),
      ],
    );
  }

  Widget _buildPlanOption(
      String value, String title, String subtitle, IconData icon) {
    return RadioListTile<String>(
      value: value,
      groupValue: selectedPlan,
      onChanged: (v) => setState(() => selectedPlan = v!),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      secondary: Icon(icon, color: AppTheme.primaryColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(
          color:
              selectedPlan == value ? AppTheme.primaryColor : Colors.grey[300]!,
        ),
      ),
    );
  }

  // STEP 3: Confirmation
  Widget _buildConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm Your Details',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Review your information before completing registration',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: AppTheme.paddingLarge),
        _buildInfoCard(
          'Account Information',
          [
            _buildInfoRow('Name', fullNameController.text),
            _buildInfoRow('Email', emailController.text),
            _buildInfoRow('Phone', phoneController.text),
          ],
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        _buildInfoCard(
          'Organization',
          [
            _buildInfoRow('Name', orgNameController.text),
            _buildInfoRow(
                'Subdomain', '${orgSubdomainController.text}.smsgateway.app'),
            _buildInfoRow('Plan', selectedPlan.toUpperCase()),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.errorColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage!,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading ? null : _previousStep,
              child: const Text('Back'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: AppTheme.paddingMedium),
        Expanded(
          child: ElevatedButton(
            onPressed: isLoading ? null : _nextStep,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(_currentStep == 2 ? 'Complete Registration' : 'Next'),
          ),
        ),
      ],
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        errorMessage = null;
      });
    }
  }

  void _nextStep() {
    setState(() => errorMessage = null);

    if (_currentStep == 0) {
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep = 2);
      }
    } else if (_currentStep == 2) {
      _completeRegistration();
    }
  }

  Future<void> _completeRegistration() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // STEP 1: Create auth.users account
      debugPrint('📝 Creating authentication account...');
      final authResponse = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create account');
      }

      final userId = authResponse.user!.id;
      debugPrint('✅ Auth account created: $userId');

      // STEP 2: Create client (top-level organization)
      debugPrint('🏢 Creating client organization...');
      final clientResponse = await supabase
          .from('clients')
          .insert({
            'name': orgNameController.text.trim(),
            'slug': orgSubdomainController.text.trim().toLowerCase(),
            'email': emailController.text.trim(),
            'owner_id': userId,
            'is_active': true,
          })
          .select()
          .single();

      final clientId = clientResponse['id'];
      debugPrint('✅ Client created: $clientId');

      // STEP 3: Create tenant (SMS Gateway product tenant)
      debugPrint('📱 Creating SMS Gateway tenant...');
      final tenantResponse = await supabase
          .schema('sms_gateway')
          .from('tenants')
          .insert({
            'name': orgNameController.text.trim(),
            'slug': orgSubdomainController.text.trim().toLowerCase(),
            'client_id': clientId,
            'status': 'active',
          })
          .select()
          .single();

      final tenantId = tenantResponse['id'];
      debugPrint('✅ SMS Gateway tenant created: $tenantId');

      // STEP 4: Create user profile in sms_gateway.users
      debugPrint('👤 Creating user profile...');
      await supabase.schema('sms_gateway').from('users').insert({
        'id': userId,
        'email': emailController.text.trim(),
        'name': fullNameController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'role': 'owner',
        'tenant_id': tenantId,
      });
      debugPrint('✅ User profile created');

      // STEP 5: Create tenant membership
      debugPrint('🔗 Creating tenant membership...');
      await supabase.schema('sms_gateway').from('tenant_members').insert({
        'tenant_id': tenantId,
        'user_id': userId,
        'role': 'owner',
      });
      debugPrint('✅ Tenant membership created');

      // STEP 6: Initialize user settings
      debugPrint('⚙️ Initializing user settings...');
      await supabase.schema('sms_gateway').from('user_settings').insert({
        'user_id': userId,
        'tenant_id': tenantId,
        'sms_channel': 'thisPhone',
        'theme_mode': 'light',
        'language': 'en',
      });
      debugPrint('✅ User settings initialized');

      // STEP 7: Initialize tenant settings
      debugPrint('🏢 Initializing tenant settings...');
      await supabase.schema('sms_gateway').from('tenant_settings').insert({
        'tenant_id': tenantId,
        'default_sms_channel': 'thisPhone',
        'daily_sms_quota': selectedPlan == 'basic'
            ? 100
            : selectedPlan == 'pro'
                ? 1000
                : 10000,
        'monthly_sms_quota': selectedPlan == 'basic'
            ? 100
            : selectedPlan == 'pro'
                ? 1000
                : 100000,
        'enable_bulk_sms': true,
        'enable_scheduled_sms': selectedPlan != 'basic',
        'enable_api_access': selectedPlan != 'basic',
        'plan_type': selectedPlan,
      });
      debugPrint('✅ Tenant settings initialized');

      // STEP 8: Create client_product_access record (CRITICAL for login)
      debugPrint('🔐 Creating product access record...');

      // First, get the product ID for sms_gateway
      final productResponse = await supabase
          .from('products')
          .select('id')
          .eq('schema_name', 'sms_gateway')
          .single();

      final productId = productResponse['id'];

      // Create the access record
      await supabase.from('client_product_access').insert({
        'user_id': userId,
        'client_id': clientId,
        'product_id': productId,
        'tenant_id': tenantId,
        'role': 'owner',
      });
      debugPrint('✅ Product access record created');

      debugPrint('🎉 Registration complete!');

      // Show success and navigate to home
      if (!mounted) return;

      // Navigate back to root - AuthWrapper will detect the logged-in user
      // and automatically navigate to HomePage or TenantSelector
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      setState(() {
        errorMessage = 'Registration failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
}
