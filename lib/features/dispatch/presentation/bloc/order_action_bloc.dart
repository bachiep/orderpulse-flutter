import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/dispatch/domain/order_state_machine.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';

sealed class OrderActionEvent extends Equatable {
  const OrderActionEvent();

  @override
  List<Object?> get props => [];
}

final class OrderTransitionRequested extends OrderActionEvent {
  const OrderTransitionRequested({
    required this.order,
    required this.targetStatus,
    this.rejectionReason,
  });

  final Order order;
  final OrderStatus targetStatus;
  final String? rejectionReason;

  @override
  List<Object?> get props => [order, targetStatus, rejectionReason];
}

final class OrderActionReset extends OrderActionEvent {
  const OrderActionReset();
}

sealed class OrderActionState extends Equatable {
  const OrderActionState();

  @override
  List<Object?> get props => [];
}

final class OrderActionIdle extends OrderActionState {
  const OrderActionIdle();
}

final class OrderActionInProgress extends OrderActionState {
  const OrderActionInProgress({
    required this.orderId,
    required this.targetStatus,
  });

  final String orderId;
  final OrderStatus targetStatus;

  @override
  List<Object?> get props => [orderId, targetStatus];
}

final class OrderActionSuccess extends OrderActionState {
  const OrderActionSuccess(this.updatedOrder);

  final Order updatedOrder;

  @override
  List<Object?> get props => [updatedOrder];
}

final class OrderActionFailure extends OrderActionState {
  const OrderActionFailure({
    required this.orderId,
    required this.message,
  });

  final String orderId;
  final String message;

  @override
  List<Object?> get props => [orderId, message];
}

/// Processes order dispatch transitions with `droppable()` to prevent double-tap writes.
class OrderActionBloc extends Bloc<OrderActionEvent, OrderActionState> {
  OrderActionBloc({
    required OrderRepository orderRepository,
  })  : _orderRepository = orderRepository,
        super(const OrderActionIdle()) {
    on<OrderTransitionRequested>(
      _onTransitionRequested,
      transformer: droppable(),
    );
    on<OrderActionReset>((_, emit) => emit(const OrderActionIdle()));
  }

  final OrderRepository _orderRepository;

  Future<void> _onTransitionRequested(
    OrderTransitionRequested event,
    Emitter<OrderActionState> emit,
  ) async {
    final validation = OrderStateMachine.validateTransition(
      event.order.status,
      event.targetStatus,
      reason: event.rejectionReason,
    );

    if (validation case Err<OrderStatus>(:final failure)) {
      emit(
        OrderActionFailure(
          orderId: event.order.id,
          message: failure.message,
        ),
      );
      return;
    }

    emit(
      OrderActionInProgress(
        orderId: event.order.id,
        targetStatus: event.targetStatus,
      ),
    );

    final result = await _orderRepository.transitionOrder(
      orderId: event.order.id,
      targetStatus: event.targetStatus,
      rejectionReason: event.rejectionReason?.trim(),
    );

    switch (result) {
      case Success<Order>(:final value):
        emit(OrderActionSuccess(value));
      case Err<Order>(:final failure):
        emit(
          OrderActionFailure(
            orderId: event.order.id,
            message: failure.message,
          ),
        );
    }
  }
}
