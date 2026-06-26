/// App-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Busana Prima';
  static const String appTagline = 'Your Fashion, Your Way';

  // Animation Durations
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);

  // Image Sizes
  static const double avatarSmall = 32;
  static const double avatarMedium = 48;
  static const double avatarLarge = 80;

  // Pagination
  static const int pageSize = 20;

  // Validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
  static const int maxNotesLength = 500;
}
