import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';

class ShiftInsightsState extends Equatable {
  const ShiftInsightsState({
    this.orders = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Order> orders;
  final bool isLoading;
  final String? errorMessage;

  ShiftInsightsState copyWith({
    List<Order>? orders,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ShiftInsightsState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [orders, isLoading, errorMessage];
}

/// Fetches the complete shift order dataset for analytics and applies live order updates.
class ShiftInsightsCubit extends Cubit<ShiftInsightsState> {
  ShiftInsightsCubit({required OrderRepository orderRepository})
      : _orderRepository = orderRepository,
        super(const ShiftInsightsState());

  final OrderRepository _orderRepository;

  Future<void> loadShiftOrders() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final result = await _orderRepository.fetchOrders(page: 1, pageSize: 100);
    if (isClosed) return;
    switch (result) {
      case Success<OrderPage>(:final value):
        emit(
          state.copyWith(
            orders: value.items,
            isLoading: false,
            clearError: true,
          ),
        );
      case Err<OrderPage>(:final failure):
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          ),
        );
    }
  }

  void upsertOrder(Order order) {
    final next = List<Order>.from(state.orders);
    final idx = next.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      next[idx] = order;
    } else {
      next.insert(0, order);
    }
    emit(state.copyWith(orders: next));
  }
}
