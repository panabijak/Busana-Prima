import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../profile/providers/profile_provider.dart';

/// Dynamic greeting header that shows the user's name from Firestore.
/// Falls back to "Guest" while loading.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider);

    final greeting = _getGreeting();
    final userName = profileAsync.when(
      data: (profile) => profile?.fullName.split(' ').first ?? 'Guest',
      loading: () => 'Guest',
      error: (_, __) => 'Guest',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(userName, style: AppTextStyles.heading2),
      ],
    );
  }

  /// Returns a time-based greeting
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}
