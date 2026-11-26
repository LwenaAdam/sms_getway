import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/tenant_service.dart';
import 'services/local_data_service.dart';
import 'services/api_sms_queue_service.dart';
import 'screens/contacts_screen.dart';
import 'screens/bulk_sms_screen.dart';
import 'screens/sms_logs_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/api_settings_screen.dart';
import 'screens/tenant_selector_screen.dart';
import 'screens/complete_registration_page.dart';
import 'screens/download_app_banner.dart';
import 'screens/billing_screen.dart';
import 'services/provider_manager_service.dart';
import 'services/app_update_service.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/responsive_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    if (AppConstants.supabaseUrl.isEmpty ||
        AppConstants.supabaseAnonKey.isEmpty) {
      debugPrint('⚠️ WARNING: SUPABASE_URL or SUPABASE_ANON_KEY is not set!');
      debugPrint('👉 Run with: flutter run --dart-define-from-file=.env');
    }
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
    );
    debugPrint('✅ Supabase initialized successfully!');
  } catch (e) {
    debugPrint('❌ Supabase initialization error: $e');
  }

  // Initialize TenantService
  await TenantService().initialize();

  // Initialize LocalDataService (offline-first)
  await LocalDataService().initialize();

  // Initialize ProviderManagerService (dynamic SMS & Payment Gateways)
  await ProviderManagerService().init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      // Use a key to force complete rebuild when theme changes
      // This prevents animation interpolation errors during theme transitions
      key: ValueKey('app_${themeProvider.isDarkMode}'),
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper to handle authentication and tenant selection state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingTenant = true;
  bool _needsTenantSelection = false;
  List<TenantModel> _tenants = [];
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthAndTenant();

    // Listen to Supabase auth state changes (e.g. Google OAuth redirect callback)
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('🔔 [AuthWrapper] Auth event: ${data.event}');
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed ||
          data.event == AuthChangeEvent.userUpdated) {
        _checkAuthAndTenant();
      } else if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) {
          setState(() {
            _isCheckingTenant = false;
            _needsTenantSelection = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthAndTenant() async {
    final session = Supabase.instance.client.auth.currentSession;
    final tenantService = TenantService();

    if (session == null) {
      // Not logged in
      if (mounted) {
        setState(() {
          _isCheckingTenant = false;
          _needsTenantSelection = false;
        });
      }
      return;
    }

    // User is logged in, check if tenant is already selected
    if (tenantService.hasTenant) {
      // Tenant already selected, proceed to home
      if (mounted) {
        setState(() {
          _isCheckingTenant = false;
          _needsTenantSelection = false;
        });
      }
      return;
    }

    // Load tenants for user
    bool hasAccess = await tenantService.loadTenantsForUser(session.user.id);

    // If new user (e.g. via Google OAuth) with no tenant, auto-provision workspace!
    if (!hasAccess || tenantService.tenantsCount == 0) {
      final autoCreated =
          await tenantService.autoProvisionWorkspaceForUser(session.user);
      if (autoCreated) {
        hasAccess = await tenantService.loadTenantsForUser(session.user.id);
      }
    }

    if (!hasAccess || tenantService.tenantsCount == 0) {
      // No access - will show error on home page or redirect to login
      if (mounted) {
        setState(() {
          _isCheckingTenant = false;
          _needsTenantSelection = false;
        });
      }
      return;
    }

    if (mounted) {
      // Check if user needs to pick tenant (2+ tenants)
      if (tenantService.shouldShowTenantPicker) {
        setState(() {
          _tenants = tenantService.tenants;
          _needsTenantSelection = true;
          _isCheckingTenant = false;
        });
      } else {
        // Single tenant, already auto-selected
        setState(() {
          _isCheckingTenant = false;
          _needsTenantSelection = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    // ✅ IMPROVED: Show branded loading screen while checking tenant
    if (_isCheckingTenant) {
      return Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sms,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'SMS Gateway Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Professional Bulk SMS Management',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading workspace...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Not logged in
    if (session == null) {
      return const LoginPage();
    }

    // Needs tenant selection (2+ tenants)
    if (_needsTenantSelection && _tenants.isNotEmpty) {
      return TenantSelectorScreen(
        tenants: _tenants,
      );
    }

    // Logged in with tenant selected
    return const HomePage();
  }
}

/// Login Page
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool isGoogleLoading = false;
  bool _obscurePassword = true;
  String? errorMessage;

  String _formatAuthError(dynamic e) {
    if (e == null) return 'An error occurred during authentication.';

    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials')) {
        return 'Incorrect email or password. Please verify and try again.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Your email has not been confirmed yet. Please check your inbox for the confirmation link.';
      }
      if (e.statusCode == '404' || msg.contains('404')) {
        return 'Authentication service is unreachable. Please verify your connection.';
      }
      if (e.statusCode == '422' || msg.contains('already registered')) {
        return 'An account with this email already exists.';
      }
      return e.message;
    }

    final str = e.toString().toLowerCase();
    if (str.contains('invalid login credentials') ||
        str.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please verify and try again.';
    }
    if (str.contains('404') ||
        str.contains('empty response with status code 404')) {
      return 'Authentication service unreachable (404). Please check your connection or restart the app.';
    }
    if (str.contains('network') ||
        str.contains('failed host lookup') ||
        str.contains('socketexception')) {
      return 'Network connection error. Please check your internet connection.';
    }
    if (str.contains('rate limit') || str.contains('too many requests')) {
      return 'Too many login attempts. Please wait a moment before trying again.';
    }

    String clean = e.toString();
    clean = clean.replaceAll(
        RegExp(
            r'^(Exception|AuthException|AuthApiException|AuthUnknownException):\s*'),
        '');
    clean = clean.replaceAll(
        RegExp(r'AuthUnknownException\(message:\s*([^,]+).*?\)', dotAll: true),
        r'$1');
    clean = clean.replaceAll(
        RegExp(r'AuthApiException\(message:\s*([^,]+).*?\)', dotAll: true),
        r'$1');
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveAuthCard(
          maxWidth: 460,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Download App Banner for web users
              const DownloadAppBanner(),
              const SizedBox(height: 20),
              // Logo or Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sms,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: AppTheme.paddingMedium),
              Text(
                'SMS Gateway',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Professional Bulk SMS Management',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.paddingLarge),
            // Email field
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            // Password field
            TextField(
              controller: passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                  ),
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            // Error message
            if (errorMessage != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            if (errorMessage != null)
              const SizedBox(height: AppTheme.paddingLarge),
            // Login button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading || isGoogleLoading ? null : _login,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Login'),
              ),
            ),
            const SizedBox(height: AppTheme.paddingMedium),

            // OR Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: AppTheme.paddingMedium),

            // Official Google Sign-In Button
            GoogleSignInButton(
              isLoading: isGoogleLoading,
              onPressed:
                  (isLoading || isGoogleLoading) ? null : _signInWithGoogle,
            ),
            const SizedBox(height: AppTheme.paddingLarge),

            // Sign up link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                GestureDetector(
                  onTap: isLoading || isGoogleLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CompleteRegistrationPage(),
                            ),
                          );
                        },
                  child: Text(
                    'Sign Up',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            const Divider(),
            const SizedBox(height: AppTheme.paddingSmall),
            // Direct API Documentation Access Button
            TextButton.icon(
              onPressed: () async {
                if (kIsWeb) {
                  final uri = Uri.parse('/api-docs.html');
                  await launchUrl(uri);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ApiSettingsScreen(),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.menu_book, size: 18),
              label: const Text('View Developer API Documentation'),
            ),
          ],
        ),
      ),
    ),
  );
  }

  void _signInWithGoogle() async {
    setState(() {
      isGoogleLoading = true;
      errorMessage = null;
    });

    try {
      // Dynamic multiplatform redirect URL:
      // - Web: Uses current domain origin (e.g. https://smsgetway.techware.africa/)
      // - Mobile: Uses Android deep link scheme (io.supabase.smsgetway://login-callback)
      final String? redirectUrl = kIsWeb
          ? (Uri.base.hasAuthority ? '${Uri.base.origin}/' : null)
          : 'io.supabase.smsgetway://login-callback';

      debugPrint(
          '🔑 Starting Google OAuth with redirect: $redirectUrl (platform: ${kIsWeb ? "Web" : "Mobile"})');

      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('❌ Google sign-in error: $e');
      if (mounted) {
        setState(() {
          errorMessage = _formatAuthError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isGoogleLoading = false;
        });
      }
    }
  }

  void _login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'Email and password are required';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth
          .signInWithPassword(
            email: emailController.text,
            password: passwordController.text,
          )
          .timeout(const Duration(seconds: 10));

      if (response.user != null && mounted) {
        debugPrint('✅ Login successful: ${response.user!.email}');

        // Load tenants for user
        final tenantService = TenantService();
        bool hasAccess =
            await tenantService.loadTenantsForUser(response.user!.id);

        if (!hasAccess || tenantService.tenantsCount == 0) {
          final autoCreated =
              await tenantService.autoProvisionWorkspaceForUser(response.user!);
          if (autoCreated) {
            hasAccess =
                await tenantService.loadTenantsForUser(response.user!.id);
          }
        }

        if (!hasAccess || tenantService.tenantsCount == 0) {
          setState(() {
            errorMessage =
                'You do not have access to SMS Gateway. Contact your administrator.';
            isLoading = false;
          });
          // Sign out since user has no access
          await Supabase.instance.client.auth.signOut();
          return;
        }

        if (mounted) {
          // Check if user needs to pick tenant (2+ tenants)
          if (tenantService.shouldShowTenantPicker) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => TenantSelectorScreen(
                  tenants: tenantService.tenants,
                ),
              ),
            );
          } else {
            // Single tenant, already auto-selected
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = _formatAuthError(e);
      });
      debugPrint('❌ Login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

/// Home Page (Main Dashboard)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? currentUserEmail;
  String? currentUserName;
  String? currentTenantName;
  int contactCount = 0;
  int groupCount = 0;
  int smsLogCount = 0;
  bool isLoading = true;
  int _currentIndex = 0;
  int _pendingCount = 0; // Track pending sync count

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkAndPromptSmsPermissionOnLaunch();
    // Check for app updates/bugfixes in background on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          AppUpdateService().checkForUpdates(context);
        }
      });
    });
  }

  /// Proactively prompt for SMS & Phone permissions on launch for Android Gateway
  Future<void> _checkAndPromptSmsPermissionOnLaunch() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      // Delay slightly until UI has stabilized
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      final smsStatus = await Permission.sms.status;
      if (!smsStatus.isGranted) {
        debugPrint('📱 App Launch: Requesting SMS permission for Gateway functionality...');
        await Permission.sms.request();
      }

      final phoneStatus = await Permission.phone.status;
      if (!phoneStatus.isGranted) {
        await Permission.phone.request();
      }
    } catch (e) {
      debugPrint('⚠️ Error requesting permissions on launch: $e');
    }
  }

  void _loadData() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      final tenantService = TenantService();
      final tenantId = tenantService.tenantId;

      if (authUser != null && tenantId != null) {
        setState(() {
          currentUserEmail = authUser.email;
          currentTenantName = tenantService.tenantName;
        });

        // Fetch profile display name/phone from sms_gateway.users if available
        try {
          final profile = await Supabase.instance.client
              .schema('sms_gateway')
              .from('users')
              .select('name, phone_number')
              .eq('id', authUser.id)
              .maybeSingle();

          if (profile != null && mounted) {
            setState(() {
              currentUserName = profile['name'] as String?;
            });
          }
        } catch (e) {
          debugPrint('⚠️ Unable to load profile name: $e');
        }

        // ✅ OPTIMIZATION 1: Load local data FIRST (instant UI update)
        final localCounts = await LocalDataService().getDashboardCounts();
        final pendingCount = await LocalDataService().getPendingSyncCount();

        debugPrint('📊 Pending sync count: $pendingCount');

        if (mounted) {
          setState(() {
            contactCount = localCounts['contacts'] ?? 0;
            groupCount = localCounts['groups'] ?? 0;
            smsLogCount = localCounts['smsLogs'] ?? 0;
            _pendingCount = pendingCount;
            isLoading = false; // ✅ Show UI immediately with cached data
          });
        }

        // ✅ OPTIMIZATION 2: Sync in background (non-blocking)
        // Use unawaited to make it truly async - don't block UI
        _syncDataInBackground(tenantId);

        // Auto-start API SMS Queue if configured
        _autoStartApiQueue();

        if (kIsWeb) {
          await _showWebStorageNoticeOnce();
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _showWebStorageNoticeOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('web_storage_notice_shown') ?? false;
    if (shown || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Web uses cloud storage only. Offline local database is not available.',
        ),
        duration: Duration(seconds: 4),
      ),
    );

    await prefs.setBool('web_storage_notice_shown', true);
  }

  /// ✅ NEW: Background sync - updates UI when complete
  Future<void> _syncDataInBackground(String tenantId) async {
    try {
      debugPrint('🔄 Starting background data sync...');

      // ✅ OPTIMIZATION: Skip full sync if we have local data (lazy load)
      // Only pull initial data if local database is empty
      final localCounts = await LocalDataService().getDashboardCounts();
      final hasLocalData = (localCounts['contacts'] ?? 0) > 0;

      if (!hasLocalData) {
        debugPrint('📥 First launch - pulling initial data...');
        await LocalDataService().loadTenantData(tenantId);
        debugPrint('✅ Initial data pull complete');
      } else {
        debugPrint('⏭️ Skipping initial sync - local data exists');
      }

      // Refresh counts after sync (if we did sync)
      if (!hasLocalData) {
        final updatedCounts = await LocalDataService().getDashboardCounts();

        if (mounted) {
          setState(() {
            contactCount = updatedCounts['contacts'] ?? 0;
            groupCount = updatedCounts['groups'] ?? 0;
            smsLogCount = updatedCounts['smsLogs'] ?? 0;
          });
        }
      }

      debugPrint('✅ Background sync complete');
    } catch (e) {
      debugPrint('⚠️ Background sync failed: $e');
      // Don't show error - app already has local data
    }
  }

  /// Auto-start the API SMS Queue service if user has enabled it in settings
  Future<void> _autoStartApiQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoStart = prefs.getBool('api_queue_auto_start') ?? false;

      if (autoStart) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          final status = await Permission.sms.status;
          if (!status.isGranted) {
            final req = await Permission.sms.request();
            if (!req.isGranted) {
              debugPrint('⚠️ Auto-start API Queue skipped: SMS permission not granted');
              return;
            }
          }
        }
        final queueService = ApiSmsQueueService();
        if (!queueService.isEnabled) {
          await queueService.start();
          debugPrint('✅ Auto-started API SMS Queue Service');
        }
      }
    } catch (e) {
      debugPrint('❌ Error auto-starting API queue: $e');
    }
  }

  /// ⚠️ EMERGENCY FIX: Mark all pending contacts as synced
  Future<void> _fixSyncStatus() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Sync Status'),
        content: Text(
          'This will mark all $_pendingCount pending contacts as synced.\n\n'
          'Only use this if these contacts already exist in the cloud and shouldn\'t be synced again.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fix Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show progress
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Fixing sync status...'),
            ],
          ),
        ),
      );
    }

    try {
      final fixed = await LocalDataService().markAllContactsAsSynced();

      // Reload pending count
      final newPendingCount = await LocalDataService().getPendingSyncCount();

      if (mounted) {
        Navigator.pop(context); // Close progress

        setState(() {
          _pendingCount = newPendingCount;
        });

        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Fixed $fixed contacts. Pending: $newPendingCount'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboard(),
      const ContactsScreen(),
      BulkSmsScreen(
        onNavigateToLogs: () {
          setState(() {
            _currentIndex = 3; // Navigate to Logs tab
          });
        },
      ),
      const SmsLogsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Gateway'),
        elevation: 0,
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.send),
            label: 'Send',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildDashboard() {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : RefreshIndicator(
            onRefresh: () async {
              // ✅ Force fresh sync from Supabase on pull-to-refresh
              setState(() => isLoading = true);

              final tenantId = TenantService().tenantId;
              if (tenantId != null) {
                // Clear cache timestamp to force fresh pull
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('last_pull_$tenantId');

                // Reload data
                _loadData();
              }

              setState(() => isLoading = false);
            },
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.paddingLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Download App Banner for web users
                        const DownloadAppBanner(),
                        const SizedBox(height: AppTheme.paddingMedium),
                        // Welcome card
                        Card(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(AppTheme.paddingLarge),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome! 👋',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(
                                  height: AppTheme.paddingSmall,
                                ),
                                Text(
                                  currentTenantName ?? 'Workspace',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentUserName?.isNotEmpty == true
                                      ? currentUserName!
                                      : (currentUserEmail ?? 'User'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.paddingLarge),
                        // Statistics
                        Text(
                          'Quick Stats',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppTheme.paddingMedium),
                        // Responsive grid that adapts to screen size
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculate responsive columns
                            int crossAxisCount = 2; // Default for mobile
                            double childAspectRatio = 1.0;

                            if (constraints.maxWidth > 1200) {
                              // Large desktop
                              crossAxisCount = 4;
                              childAspectRatio = 1.3;
                            } else if (constraints.maxWidth > 800) {
                              // Tablet/small desktop
                              crossAxisCount = 3;
                              childAspectRatio = 1.2;
                            } else if (constraints.maxWidth > 600) {
                              // Large phone/small tablet
                              crossAxisCount = 2;
                              childAspectRatio = 1.1;
                            }

                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: AppTheme.paddingMedium,
                              crossAxisSpacing: AppTheme.paddingMedium,
                              childAspectRatio: childAspectRatio,
                              children: [
                                _buildStatCard(
                                  context,
                                  icon: Icons.contacts,
                                  label: 'Contacts',
                                  value: '$contactCount',
                                  color: Colors.blue,
                                ),
                                _buildStatCard(
                                  context,
                                  icon: Icons.group,
                                  label: 'Groups',
                                  value: '$groupCount',
                                  color: Colors.green,
                                ),
                                _buildStatCard(
                                  context,
                                  icon: Icons.mail,
                                  label: 'SMS Logs',
                                  value: '$smsLogCount',
                                  color: Colors.orange,
                                ),
                                _buildStatCard(
                                  context,
                                  icon: Icons.info,
                                  label: 'Status',
                                  value: 'Active',
                                  color: Colors.purple,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppTheme.paddingLarge),

                        // API & Developer Quick Access Card
                        Card(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(AppTheme.paddingMedium),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 450;

                                final buttons = Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ApiSettingsScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.key, size: 18),
                                      label: const Text('API Keys'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const BillingScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                          Icons.account_balance_wallet,
                                          size: 18,
                                          color: Colors.teal),
                                      label: const Text('Billing & Plans'),
                                    ),
                                    if (kIsWeb)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final uri =
                                              Uri.parse('/api-docs.html');
                                          await launchUrl(uri);
                                        },
                                        icon: const Icon(Icons.open_in_new,
                                            size: 18),
                                        label: const Text('View Docs'),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ApiSettingsScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.description,
                                            size: 18),
                                        label: const Text('API Docs'),
                                      ),
                                  ],
                                );

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              Icons.api,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Developer API & Docs',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Integrate SMS delivery into external apps and webhooks',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      buttons,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.api,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Developer API & Docs',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Integrate SMS delivery into external apps and webhooks',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    buttons,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.paddingLarge),

                        // ⚠️ EMERGENCY FIX BUTTON - Remove after fixing sync
                        if (_pendingCount > 1000) // Only show if many pending
                          Card(
                            color: Colors.orange.shade50,
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(AppTheme.paddingMedium),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warning,
                                          color: Colors.orange),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Sync Issue Detected',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You have $_pendingCount contacts waiting to sync. '
                                    'If these contacts already exist in the cloud, use this fix:',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _fixSyncStatus,
                                    icon: const Icon(Icons.build),
                                    label: const Text('Fix Sync Status'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
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
              ),
            ),
          );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: AppTheme.paddingSmall),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: color),
            ),
            const SizedBox(height: AppTheme.paddingSmall),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
