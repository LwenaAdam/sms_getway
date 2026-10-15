import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';

/// Download App Banner - Shows on web version encouraging users to download Android app
class DownloadAppBanner extends StatefulWidget {
  const DownloadAppBanner({super.key});

  @override
  State<DownloadAppBanner> createState() => _DownloadAppBannerState();
}

class _DownloadAppBannerState extends State<DownloadAppBanner> {
  bool _isDismissed = false;

  Future<void> _launchURL() async {
    final url = Uri.parse(
      'https://github.com/LWENA27/sms_getway/releases/download/v1.1.0/sms_gateway_pro_v1.1.0.apk',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on web
    if (!kIsWeb || _isDismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF764ba2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.smartphone,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Want full SMS functionality?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Download the Android app for native SMS sending',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _launchURL,
            icon: const Icon(Icons.download, size: 16),
            label: const Text(
              'GET APP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isDismissed = true;
              });
            },
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 20,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}

/// Compact version for smaller spaces
class DownloadAppBannerCompact extends StatelessWidget {
  const DownloadAppBannerCompact({super.key});

  Future<void> _launchURL() async {
    final url = Uri.parse(
      'https://github.com/LWENA27/sms_getway/releases/download/v1.1.0/sms_gateway_pro_v1.1.0.apk',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on web
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: _launchURL,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.android, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Download Android App',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
