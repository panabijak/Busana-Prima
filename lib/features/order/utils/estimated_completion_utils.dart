import 'package:intl/intl.dart';

import '../models/order_model.dart';

/// Firestore field written by the tailor app (per order item):
/// `orders/{orderId}.items[].estimatedCompletionDate`
DateTime? itemEstimatedCompletionDate(OrderItem item) =>
    item.estimatedCompletionDate;

/// Resolves order-level ETA display from [OrderItem.estimatedCompletionDate] values.
EstimatedCompletionDisplay resolveOrderEstimatedCompletion(BusanaOrder order) {
  final itemDates = order.items
      .map(itemEstimatedCompletionDate)
      .whereType<DateTime>()
      .toList();

  if (itemDates.isEmpty) {
    return EstimatedCompletionDisplay.pending;
  }

  itemDates.sort();
  if (itemDates.length == 1) {
    return EstimatedCompletionDisplay.single(itemDates.first);
  }

  final earliest = itemDates.first;
  final latest = itemDates.last;
  if (_isSameDay(earliest, latest)) {
    return EstimatedCompletionDisplay.single(earliest);
  }
  return EstimatedCompletionDisplay.range(earliest, latest);
}

class EstimatedCompletionDisplay {
  final DateTime? singleDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  const EstimatedCompletionDisplay._({
    this.singleDate,
    this.rangeStart,
    this.rangeEnd,
  });

  static const pending = EstimatedCompletionDisplay._();

  factory EstimatedCompletionDisplay.single(DateTime date) {
    return EstimatedCompletionDisplay._(singleDate: date);
  }

  factory EstimatedCompletionDisplay.range(DateTime start, DateTime end) {
    return EstimatedCompletionDisplay._(rangeStart: start, rangeEnd: end);
  }

  bool get hasDate => singleDate != null || rangeStart != null;

  String format({String pattern = 'd MMM yyyy'}) {
    if (singleDate != null) {
      return DateFormat(pattern).format(singleDate!);
    }
    if (rangeStart != null && rangeEnd != null) {
      return '${DateFormat('d MMM').format(rangeStart!)} – ${DateFormat(pattern).format(rangeEnd!)}';
    }
    return '';
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
