import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme.dart';
import '../providers/auth_provider.dart';

/// Loading / Splash screen for Busana Prima
///
/// Displays the brand logo on a deep purple background.
/// Checks Firebase auth state to determine navigation:
/// - If user is signed in → go to home (auto-login / persistent session)
/// - If not signed in → go to login
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state and navigate accordingly
    ref.listen<AsyncValue>(authStateProvider, (previous, next) {
      next.whenData((user) {
        // Small delay for splash animation to play
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          if (user != null) {
            // User is signed in → check email verification
            if (user.emailVerified ||
                user.providerData.any((p) => p.providerId == 'google.com')) {
              context.go(AppRoutes.home);
            } else {
              context.go(AppRoutes.emailVerification);
            }
          } else {
            context.go(AppRoutes.login);
          }
        });
      });
    });

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280, maxHeight: 280),
              child: Image.asset(
                'assets/images/busana_prima_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
