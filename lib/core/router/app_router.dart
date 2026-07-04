import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/email_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/loading_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/registration_success_screen.dart';
import '../../features/home/screens/main_shell_screen.dart';
import '../../features/product/screens/product_details_screen.dart';
import '../../features/product/screens/product_options_screen.dart';
import '../../features/try_on/screens/try_on_screen.dart';
import '../../features/cart/screens/shopping_cart_screen.dart';
import '../../features/checkout/screens/checkout_dropoff_screen.dart';
import '../../features/checkout/screens/checkout_shipping_screen.dart';
import '../../features/checkout/screens/order_confirmation_screen.dart';
import '../../features/order/screens/order_status_screen.dart';
import '../../features/order/screens/outfit_details_screen.dart';
import '../../features/order/screens/send_review_screen.dart';
import '../../features/order/screens/order_page_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/chat/screens/conversation_list_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/favourites_screen.dart';
import '../../features/profile/screens/address_list_screen.dart';
import '../../features/digital_tailor/screens/calibration_screen.dart';
import '../../features/digital_tailor/screens/scanner_screen.dart';
import '../../features/digital_tailor/screens/results_screen.dart';
import '../../features/digital_tailor/screens/profile_list_screen.dart';

/// Route names for type-safe navigation
class AppRoutes {
  AppRoutes._();

  // Auth
  static const String loading = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String registrationSuccess = '/registration-success';
  static const String forgotPassword = '/forgot-password';
  static const String emailVerification = '/email-verification';

  // Main (with bottom nav)
  static const String home = '/home';

  // Shopping
  static const String productDetails = '/product/:id';
  static const String productOptions = '/product/:id/options';
  static const String tryOn = '/product/:id/try-on';
  static const String shoppingCart = '/cart';

  // Checkout
  static const String checkoutDropoff = '/checkout/dropoff';
  static const String checkoutShipping = '/checkout/shipping';
  static const String orderConfirmation = '/order-confirmation';

  // Orders
  static const String orderStatus = '/orders/:id/status';
  static const String outfitDetails = '/orders/:id/details';
  static const String sendReview = '/orders/:id/review';
  static const String orderPage = '/orders';

  // Communication
  static const String chat = '/chat';
  static const String orderChat = '/orders/:id/chat';

  // Profile
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String favourites = '/profile/favourites';
  static const String addresses = '/profile/addresses';

  // Digital Tailor
  static const String measurements = '/digital-tailor/measurements';
  static const String digitalTailorCalibration = '/digital-tailor/calibration';
  static const String digitalTailorScanner = '/digital-tailor/scanner';
  static const String digitalTailorResults = '/digital-tailor/results';
}

/// App router configuration
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.loading,
  debugLogDiagnostics: false,
  routes: [
    // Auth Flow
    GoRoute(
      path: AppRoutes.loading,
      builder: (context, state) => const LoadingScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.registrationSuccess,
      builder: (context, state) => const RegistrationSuccessScreen(),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.emailVerification,
      builder: (context, state) => const EmailVerificationScreen(),
    ),

    // Main Shell (Home with bottom nav)
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const MainShellScreen(),
    ),

    // Shopping Flow
    GoRoute(
      path: AppRoutes.productDetails,
      builder: (context, state) =>
          ProductDetailsScreen(productId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.productOptions,
      builder: (context, state) =>
          ProductOptionsScreen(productId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.tryOn,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? const {};
        return TryOnScreen(
          productId: state.pathParameters['id'] ?? '',
          productName: (args['productName'] as String?) ?? 'Virtual Try-On',
          transparentUrl: (args['transparentUrl'] as String?) ?? '',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.shoppingCart,
      builder: (context, state) => const ShoppingCartScreen(),
    ),

    // Checkout Flow
    GoRoute(
      path: AppRoutes.checkoutDropoff,
      builder: (context, state) => const CheckoutDropoffScreen(),
    ),
    GoRoute(
      path: AppRoutes.checkoutShipping,
      builder: (context, state) => const CheckoutShippingScreen(),
    ),
    GoRoute(
      path: AppRoutes.orderConfirmation,
      builder: (context, state) => const OrderConfirmationScreen(),
    ),

    // Order Management
    GoRoute(
      path: AppRoutes.orderPage,
      builder: (context, state) => const OrderPageScreen(),
    ),
    GoRoute(
      path: AppRoutes.orderStatus,
      builder: (context, state) =>
          OrderStatusScreen(orderId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: AppRoutes.outfitDetails,
      builder: (context, state) => OutfitDetailsScreen(
        orderId: state.pathParameters['id'] ?? '',
        itemIndex: int.tryParse(state.uri.queryParameters['item'] ?? '0') ?? 0,
      ),
    ),
    GoRoute(
      path: AppRoutes.sendReview,
      builder: (context, state) =>
          SendReviewScreen(orderId: state.pathParameters['id'] ?? ''),
    ),

    // Communication
    GoRoute(
      path: AppRoutes.chat,
      builder: (context, state) => const ConversationListScreen(),
    ),
    GoRoute(
      path: AppRoutes.orderChat,
      builder: (context, state) =>
          ChatScreen(orderId: state.pathParameters['id'] ?? ''),
    ),

    // Profile
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.editProfile,
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.favourites,
      builder: (context, state) => const FavouritesScreen(),
    ),
    GoRoute(
      path: AppRoutes.addresses,
      builder: (context, state) => const AddressListScreen(),
    ),

    // Digital Tailor
    GoRoute(
      path: AppRoutes.measurements,
      builder: (context, state) => const ProfileListScreen(),
    ),
    GoRoute(
      path: AppRoutes.digitalTailorCalibration,
      builder: (context, state) => const CalibrationScreen(),
    ),
    GoRoute(
      path: AppRoutes.digitalTailorScanner,
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: AppRoutes.digitalTailorResults,
      builder: (context, state) => const ResultsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Page not found', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${state.uri}', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  ),
);
