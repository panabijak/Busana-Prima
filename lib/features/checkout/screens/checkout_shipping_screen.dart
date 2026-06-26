import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

/// Checkout Shipping Screen - redirects to the unified checkout screen.
/// Kept for route compatibility.
class CheckoutShippingScreen extends StatelessWidget {
  const CheckoutShippingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect to the unified checkout screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go(AppRoutes.checkoutDropoff);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
