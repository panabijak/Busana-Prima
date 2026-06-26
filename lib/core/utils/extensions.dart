import 'package:flutter/material.dart';

/// Extension on BuildContext for quick access to theme and media query
extension BuildContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
  double get bottomInset => MediaQuery.viewInsetsOf(this).bottom;
}

/// Extension on int for price formatting (Indonesian Rupiah)
extension PriceFormatting on int {
  String get toRupiah {
    final formatted = toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }
}

/// Extension on double for price formatting
extension DoublePriceFormatting on double {
  String get toRupiah {
    return toInt().toRupiah;
  }
}

/// Extension on DateTime for display formatting
extension DateTimeFormatting on DateTime {
  String get toDisplayDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[month - 1]} $day, $year';
  }

  String get toDisplayTime {
    final h = hour > 12 ? hour - 12 : hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  String get toDisplayDateTime => '$toDisplayDate - $toDisplayTime';
}
