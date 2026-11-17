import 'package:orderpulse_flutter/core/error/failures.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// Pure domain state machine governing valid merchant order dispatch transitions.
abstract final class OrderStateMachine {
  static const Map<OrderStatus, Set<OrderStatus>> _transitions = {
    OrderStatus.newOrder: {OrderStatus.preparing, OrderStatus.rejected},
    OrderStatus.preparing: {OrderStatus.ready},
    OrderStatus.ready: {OrderStatus.completed},
    OrderStatus.completed: {},
    OrderStatus.rejected: {},
  };

  /// Returns the valid next statuses reachable directly from [current].
  static Set<OrderStatus> allowedTargets(OrderStatus current) =>
      _transitions[current] ?? const {};

  static bool canTransition(OrderStatus from, OrderStatus to) =>
      allowedTargets(from).contains(to);

  static bool canAcceptAndPrepare(OrderStatus status) =>
      canTransition(status, OrderStatus.preparing);

  static bool canMarkReady(OrderStatus status) =>
      canTransition(status, OrderStatus.ready);

  static bool canHandoverComplete(OrderStatus status) =>
      canTransition(status, OrderStatus.completed);

  static bool canReject(OrderStatus status) =>
      canTransition(status, OrderStatus.rejected);

  /// Validates that [from] -> [to] is permitted and enforces mandatory rejection reasons.
  static Result<OrderStatus> validateTransition(
    OrderStatus from,
    OrderStatus to, {
    String? reason,
  }) {
    if (!canTransition(from, to)) {
      return Err(
        ValidationFailure(
          'Cannot transition order from ${from.label} to ${to.label}.',
          code: 'INVALID_STATE_TRANSITION',
        ),
      );
    }

    if (to == OrderStatus.rejected &&
        (reason == null || reason.trim().isEmpty)) {
      return const Err(
        ValidationFailure(
          'A non-empty rejection reason is required.',
          code: 'REJECTION_REASON_REQUIRED',
        ),
      );
    }

    return Success(to);
  }
}
