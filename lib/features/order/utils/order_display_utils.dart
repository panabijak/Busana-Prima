import 'package:flutter/material.dart';

import '../models/order_model.dart';

/// Consistent order-level status colors across customer screens.
Color orderStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return const Color(0xFFF59E0B);
    case OrderStatus.confirmed:
      return const Color(0xFF3B82F6);
    case OrderStatus.inProgress:
      return const Color(0xFF6366F1);
    case OrderStatus.ready:
      return const Color(0xFF10B981);
    case OrderStatus.outForDelivery:
      return const Color(0xFF0EA5E9);
    case OrderStatus.completed:
      return const Color(0xFF22C55E);
    case OrderStatus.cancelled:
      return const Color(0xFFEF4444);
  }
}

/// Tab filter groups for My Orders.
class OrderTabFilters {
  OrderTabFilters._();

  static const inTailoring = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.inProgress,
  ];

  static const ready = [
    OrderStatus.ready,
    OrderStatus.outForDelivery,
  ];

  static const completed = [OrderStatus.completed];

  static const cancelled = [OrderStatus.cancelled];
}
