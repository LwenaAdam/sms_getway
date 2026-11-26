import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

/// Model representing a remote version release configuration
class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String title;
  final List<String> releaseNotes;
  final String downloadUrl;
  final bool forceUpdate;

  AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.title,
    required this.releaseNotes,
    required this.downloadUrl,
    this.forceUpdate = false,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    List<String> notes = [];
    if (json['release_notes'] is List) {
      notes = List<String>.from(json['release_notes'].map((e) => e.toString()));
    } else if (json['release_notes'] is String) {
      notes = [json['release_notes'] as String];
    }

    return AppUpdateInfo(
      version: json['version']?.toString() ?? '1.0.0',
      buildNumber: json['build_number'] is int
          ? json['build_number'] as int
          : int.tryParse(json['build_number']?.toString() ?? '1') ?? 1,
      releaseDate: json['release_date']?.toString() ?? '',
      title: json['title']?.toString() ?? 'New Version Available',
      releaseNotes: notes,
      downloadUrl: json['download_url']?.toString() ??
          'https://smsgetway.techware.africa/download/app',
      forceUpdate: json['force_update'] == true,
    );
  }
}

/// Service that checks for new app updates, bug fixes, and triggers in-app OTA download
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  static bool _hasPromptedThisSession = false;

  /// Check whether a newer version or build number is available
  static bool isNewerVersion({
    required String remoteVersion,
    required int remoteBuild,
    required String currentVersion,
    required int currentBuild,
  }) {
    if (remoteBuild > currentBuild) return true;

    try {
      final remoteParts = remoteVersion.split('.').map(int.parse).toList();
      final currentParts = currentVersion.split('.').map(int.parse).toList();

      for (int i = 0; i < remoteParts.length && i < currentParts.length; i++) {
        if (remoteParts[i] > currentParts[i]) return true;
        if (remoteParts[i] < currentParts[i]) return false;
      }
      return remoteParts.length > currentParts.length;
    } catch (_) {
      return remoteBuild > currentBuild;
    }
  }

  /// Fetch update info from remote version.json or Supabase table
  Future<AppUpdateInfo?> fetchLatestRelease() async {
    // 1. Try public version.json on web host
    try {
      final response = await http
          .get(Uri.parse(AppConstants.appUpdateUrl))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AppUpdateInfo.fromJson(data);
      }
    } catch (e) {
      debugPrint('ℹ️ [AppUpdate] version.json check note: $e');
    }

    // 2. Fallback: Try Supabase app_versions table if online
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .schema('sms_gateway')
          .from('app_versions')
          .select()
          .eq('is_active', true)
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        return AppUpdateInfo.fromJson(res);
      }
    } catch (_) {}

    return null;
  }

  /// Automatically check for updates on launch or manually from Settings
  Future<void> checkForUpdates(
    BuildContext context, {
    bool isManualCheck = false,
  }) async {
    // On web, updates are instantaneous via page reload
    if (kIsWeb) {
      if (isManualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🌐 Web app is always up to date!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
      return;
    }

    // Prevent spamming the dialog on every screen rebuild if already shown
    if (!isManualCheck && _hasPromptedThisSession) return;

    final info = await fetchLatestRelease();
    if (info == null) {
      if (isManualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach update server. Check your connection.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final hasUpdate = isNewerVersion(
      remoteVersion: info.version,
      remoteBuild: info.buildNumber,
      currentVersion: AppConstants.appVersion,
      currentBuild: AppConstants.appBuildNumber,
    );

    if (hasUpdate) {
      _hasPromptedThisSession = true;
      if (context.mounted) {
        showUpdateDialog(context, info);
      }
    } else if (isManualCheck && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ You are using the latest version (${AppConstants.appVersion})!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Show the Update Dialog with release notes and a direct install button
  void showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch, color: Colors.teal, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Available!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'v${info.version} (Current: v${AppConstants.appVersion})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "A new version of SMS Gateway Pro is ready with bug fixes and improvements:",
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              if (info.releaseNotes.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: info.releaseNotes
                        .map(
                          (note) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: const TextStyle(fontSize: 12, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Text(
                'Tap "Update Now" to download and install. Your data and login will be preserved.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            if (!info.forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(info.downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
