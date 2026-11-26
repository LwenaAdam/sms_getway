import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Utility to detect screen breakpoints across the app
class ResponsiveBreakpoints {
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600 &&
      MediaQuery.sizeOf(context).width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;
}

/// Centers content with a clean maximum width on Desktop/Web
/// while preserving 100% full-width on mobile phones.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 850,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

/// A responsive wrapper that renders an elevated card on Desktop/Web
/// and clean native flat layout on mobile devices.
class ResponsiveAuthCard extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveAuthCard({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 650;

    if (!isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: child,
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
