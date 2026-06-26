import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/models/cart_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../../order/models/order_model.dart';
import '../../order/services/order_service.dart';

/// Singleton OrderService provider.
final orderServiceProvider = Provider((ref) => OrderService());

/// Checkout state holding all user selections for the checkout flow.
class CheckoutState {
  final DeliveryMethod deliveryMethod;
  final FabricDeliveryMethod fabricDeliveryMethod;
  final PaymentTerms paymentTerms;
  final PaymentMethod paymentMethod;
  final DateTime? fabricDropoffDate;
  final String shippingAddress;

  // Processing state
  final bool isProcessing;
  final String? processingMessage;
  final String? errorMessage;
  final BusanaOrder? completedOrder;

  const CheckoutState({
    this.deliveryMethod = DeliveryMethod.shipToAddress,
    this.fabricDeliveryMethod = FabricDeliveryMethod.dropOffAtBoutique,
    this.paymentTerms = PaymentTerms.fullPayment,
    this.paymentMethod = PaymentMethod.visa,
    this.fabricDropoffDate,
    this.shippingAddress = '',
    this.isProcessing = false,
    this.processingMessage,
    this.errorMessage,
    this.completedOrder,
  });

  CheckoutState copyWith({
    DeliveryMethod? deliveryMethod,
    FabricDeliveryMethod? fabricDeliveryMethod,
    PaymentTerms? paymentTerms,
    PaymentMethod? paymentMethod,
    DateTime? fabricDropoffDate,
    String? shippingAddress,
    bool? isProcessing,
    String? processingMessage,
    String? errorMessage,
    BusanaOrder? completedOrder,
  }) {
    return CheckoutState(
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      fabricDeliveryMethod: fabricDeliveryMethod ?? this.fabricDeliveryMethod,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      fabricDropoffDate: fabricDropoffDate ?? this.fabricDropoffDate,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      isProcessing: isProcessing ?? this.isProcessing,
      processingMessage: processingMessage,
      errorMessage: errorMessage,
      completedOrder: completedOrder,
    );
  }
}

/// Checkout state notifier managing the entire checkout flow.
class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final OrderService _orderService;
  final Ref _ref;

  CheckoutNotifier(this._orderService, this._ref)
    : super(const CheckoutState());

  void setDeliveryMethod(DeliveryMethod method) {
    state = state.copyWith(deliveryMethod: method);
  }

  void setFabricDeliveryMethod(FabricDeliveryMethod method) {
    state = state.copyWith(fabricDeliveryMethod: method);
  }

  void setPaymentTerms(PaymentTerms terms) {
    state = state.copyWith(paymentTerms: terms);
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setFabricDropoffDate(DateTime? date) {
    state = state.copyWith(fabricDropoffDate: date);
  }

  void setShippingAddress(String address) {
    state = state.copyWith(shippingAddress: address);
  }

  /// Execute the full checkout: validate → simulate payment → create order → clear cart.
  ///
  /// Cart is ONLY cleared after:
  /// 1. Order successfully written to database
  /// 2. Payment object confirmed stored
  Future<void> placeOrder({
    required List<CartItem> cartItems,
    required String customerName,
    required String customerPhone,
    required String shippingAddress,
    Map<String, dynamic>? addressSnapshot,
  }) async {
    if (cartItems.isEmpty) {
      state = state.copyWith(errorMessage: 'Cart is empty');
      return;
    }

    // Validate: fabric drop-off date required only when customer provides own fabric
    final hasOwnFabric = cartItems.any((item) => item.fabricType == 'own');
    if (hasOwnFabric &&
        state.fabricDeliveryMethod == FabricDeliveryMethod.dropOffAtBoutique &&
        state.fabricDropoffDate == null) {
      state = state.copyWith(
        errorMessage: 'Please select a fabric drop-off date',
      );
      return;
    }

    // Validate: all cart items must have measurement
    final missingMeasurement = cartItems.any(
      (item) =>
          item.measurementProfileId == null ||
          item.measurementProfileId!.isEmpty,
    );
    if (missingMeasurement) {
      state = state.copyWith(
        errorMessage:
            'All items must have completed measurements before checkout',
      );
      return;
    }

    try {
      // Step 1: Processing Payment...
      state = state.copyWith(
        isProcessing: true,
        processingMessage: 'Processing Payment...',
        errorMessage: null,
      );

      final totalAmount = cartItems.fold(
        0.0,
        (sum, item) => sum + item.lineTotal,
      );

      // FIX #6: Correct payment amount based on terms (with rounding)
      final double payableAmount;
      final double balanceRemaining;
      if (state.paymentTerms == PaymentTerms.deposit50) {
        payableAmount = double.parse((totalAmount * 0.5).toStringAsFixed(2));
        balanceRemaining = double.parse(
          (totalAmount - payableAmount).toStringAsFixed(2),
        );
      } else {
        payableAmount = totalAmount;
        balanceRemaining = 0.0;
      }

      // Step 2: Simulate payment (includes internal delay)
      state = state.copyWith(processingMessage: 'Validating Transaction...');

      final paymentRecord = await _orderService.simulatePayment(
        amount: payableAmount,
        paymentMethod: state.paymentMethod,
        paymentTerms: state.paymentTerms,
        totalOrderAmount: totalAmount,
        balanceRemaining: balanceRemaining,
      );

      // Step 3: Creating order
      state = state.copyWith(processingMessage: 'Payment Approved');
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.copyWith(processingMessage: 'Creating Order...');

      final order = await _orderService.createOrder(
        cartItems: cartItems,
        payment: paymentRecord,
        deliveryMethod: state.deliveryMethod,
        fabricDeliveryMethod: state.fabricDeliveryMethod,
        shippingAddress: shippingAddress,
        customerName: customerName,
        customerPhone: customerPhone,
        addressSnapshot: addressSnapshot,
        fabricDropoffDate: state.fabricDropoffDate,
      );

      // Step 4: Order created and payment stored — remove ONLY checked-out items
      final cartService = _ref.read(cartServiceProvider);
      final checkedOutIds = cartItems.map((item) => item.id).toList();
      await cartService.removeItems(checkedOutIds);

      // Done
      state = state.copyWith(
        isProcessing: false,
        processingMessage: null,
        completedOrder: order,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        processingMessage: null,
        errorMessage: e.toString(),
      );
    }
  }

  /// Reset state for a new checkout session.
  void reset() {
    state = const CheckoutState();
  }
}

/// Provider for the checkout notifier.
final checkoutNotifierProvider =
    StateNotifierProvider<CheckoutNotifier, CheckoutState>((ref) {
      final orderService = ref.watch(orderServiceProvider);
      return CheckoutNotifier(orderService, ref);
    });
