import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';

/// Email verification screen - prompts user to verify their email
/// Periodically checks if the email has been verified.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  Timer? _checkTimer;
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Periodically check if email is verified (every 3 seconds)
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final authService = ref.read(authServiceProvider);
      final verified = await authService.checkEmailVerified();
      if (verified && mounted) {
        _checkTimer?.cancel();
        context.go(AppRoutes.home);
      }
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resendEmail() async {
    if (!_canResend) return;

    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.resendVerification();

    // Start cooldown (60 seconds)
    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);
    final email = authService.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Email icon
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.infoLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 48,
                  color: AppColors.info,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Verify your email',
                style: AppTextStyles.heading2,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                'We\'ve sent a verification link to\n$email',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Please check your inbox and click the link to verify.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Resend button
              AppButton(
                label: _canResend
                    ? 'Resend Verification Email'
                    : 'Resend in ${_resendCooldown}s',
                onPressed: _canResend ? _resendEmail : null,
                variant: AppButtonVariant.outline,
              ),

              const SizedBox(height: 16),

              // Sign out and go back
              TextButton(
                onPressed: () async {
                  final notifier = ref.read(authNotifierProvider.notifier);
                  await notifier.signOut();
                  if (!mounted) return;
                  context.go(AppRoutes.login);
                },
                child: Text(
                  'Use a different account',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
