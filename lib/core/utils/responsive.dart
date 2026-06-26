import 'package:flutter/material.dart';

/// Responsive layout utility for handling different screen sizes
class Responsive {
  Responsive._();

  // Breakpoints
  static const double mobileBreakpoint = 360;
  static const double tabletBreakpoint = 768;
  static const double desktopBreakpoint = 1024;

  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tabletBreakpoint;

  /// Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tabletBreakpoint && width < desktopBreakpoint;
  }

  /// Check if current screen is desktop
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  /// Get screen width
  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Get screen height
  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// Get responsive value based on screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// Get responsive padding
  static double horizontalPadding(BuildContext context) {
    return value(context, mobile: 24.0, tablet: 32.0, desktop: 48.0);
  }

  /// Get grid cross axis count
  static int gridColumns(BuildContext context) {
    return value(context, mobile: 2, tablet: 3, desktop: 4);
  }
}
