import 'package:flutter/material.dart';

/// Centralized color palette for Busana Prima
/// Extracted from Figma screenshots
class AppColors {
  AppColors._();

  // Primary Colors - Deep Purple/Plum
  static const Color primary = Color(0xFF580C58);
  static const Color primaryLight = Color(0xFF7A1C7A);
  static const Color primaryDark = Color(0xFF380438);
  static const Color primarySurface = Color(0xFF490849);

  // Accent/CTA
  static const Color accent = Color(0xFF580C58);
  static const Color accentLight = Color(0xFF7A1C7A);
  static const Color accentDark = Color(0xFF380438);

  // Secondary - Blue (for some CTAs)
  static const Color blue = Color(0xFF2196F3);
  static const Color blueLight = Color(0xFF42A5F5);

  // Background Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8F8F8);
  static const Color scaffoldBackground = Color(0xFFF9F9F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B7B);
  static const Color textTertiary = Color(0xFF9E9EAE);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);
  static const Color textHint = Color(0xFFBDBDBD);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);

  // Border & Divider Colors
  static const Color border = Color(0xFFE8E8E8);
  static const Color borderLight = Color(0xFFF0F0F0);
  static const Color divider = Color(0xFFEEEEEE);

  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0D000000);

  // Input Colors
  static const Color inputFill = Color(0xFFF5F5F5);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color inputFocusBorder = Color(0xFF580C58);

  // Disabled
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color disabledBackground = Color(0xFFF5F5F5);

  // Rating
  static const Color starFilled = Color(0xFFFFB800);
  static const Color starEmpty = Color(0xFFE0E0E0);

  // Chat
  static const Color chatBubbleSent = Color(0xFF333333);
  static const Color chatBubbleReceived = Color(0xFFF0F0F0);

  // Order Status
  static const Color statusPending = Color(0xFFFF9800);
  static const Color statusConfirmed = Color(0xFF2196F3);
  static const Color statusInProgress = Color(0xFF9C27B0);
  static const Color statusReady = Color(0xFF4CAF50);
  static const Color statusCompleted = Color(0xFF388E3C);
  static const Color statusCancelled = Color(0xFFE53935);

  // Bottom Nav
  static const Color navActive = Color(0xFF580C58);
  static const Color navInactive = Color(0xFF9E9E9E);
}
