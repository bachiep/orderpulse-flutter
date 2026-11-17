import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';

sealed class OrderBoardEvent extends Equatable {
  const OrderBoardEvent();

  @override
  List<Object?> get props => [];
}

final class OrderBoardLoadRequested extends OrderBoardEvent {
  const OrderBoardLoadRequested();
}

final class OrderBoardRefreshRequested extends OrderBoardEvent {
  const OrderBoardRefreshRequested();
}

final class OrderBoardLoadMoreRequested extends OrderBoardEvent {
  const OrderBoardLoadMoreRequested();
}

final class OrderBoardFilterChanged extends OrderBoardEvent {
  const OrderBoardFilterChanged(this.filter);

  final OrderFilterTab filter;

  @override
  List<Object?> get props => [filter];
}

final class OrderBoardQueryChanged extends OrderBoardEvent {
  const OrderBoardQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class OrderBoardOrderUpserted extends OrderBoardEvent {
  const OrderBoardOrderUpserted(this.order, {this.isNewIncoming = false});

  final Order order;
  final bool isNewIncoming;

  @override
  List<Object?> get props => [order, isNewIncoming];
}

final class OrderBoardAlertDismissed extends OrderBoardEvent {
  const OrderBoardAlertDismissed();
}

sealed class OrderBoardState extends Equatable {
  const OrderBoardState({
    required this.filter,
    required this.searchQuery,
    this.stats,
  });

  final OrderFilterTab filter;
  final String searchQuery;
  final MerchantShiftStats? stats;

  @override
  List<Object?> get props => [filter, searchQuery, stats];
}

final class OrderBoardLoading extends OrderBoardState {
  const OrderBoardLoading({
    super.filter = OrderFilterTab.all,
    super.searchQuery = '',
    super.stats,
  });
}

final class OrderBoardLoaded extends OrderBoardState {
  const OrderBoardLoaded({
    required this.orders,
    required super.filter,
    required super.searchQuery,
    required this.page,
    required this.hasMore,
    required this.totalCount,
    super.stats,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.incomingAlertOrder,
  });

  final List<Order> orders;
  final int page;
  final bool hasMore;
  final int totalCount;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Order? incomingAlertOrder;

  OrderBoardLoaded copyWith({
    List<Order>? orders,
    MerchantShiftStats? stats,
    OrderFilterTab? filter,
    String? searchQuery,
    int? page,
    bool? hasMore,
    int? totalCount,
    bool? isLoadingMore,
    bool? isRefreshing,
    Order? incomingAlertOrder,
    bool clearIncomingAlert = false,
  }) {
    return OrderBoardLoaded(
      orders: orders ?? this.orders,
      stats: stats ?? this.stats,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      incomingAlertOrder: clearIncomingAlert
          ? null
          : (incomingAlertOrder ?? this.incomingAlertOrder),
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        orders,
        page,
        hasMore,
        totalCount,
        isLoadingMore,
        isRefreshing,
        incomingAlertOrder,
      ];
}

final class OrderBoardEmpty extends OrderBoardState {
  const OrderBoardEmpty({
    required super.filter,
    required super.searchQuery,
    super.stats,
  });
}

final class OrderBoardError extends OrderBoardState {
  const OrderBoardError({
    required this.message,
    required super.filter,
    required super.searchQuery,
    super.stats,
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

/// Manages paginated order fetching, filter/search reloads, and live list updates.
class OrderBoardBloc extends Bloc<OrderBoardEvent, OrderBoardState> {
  OrderBoardBloc({
    required OrderRepository orderRepository,
    this.pageSize = 8,
  })  : _orderRepository = orderRepository,
        super(const OrderBoardLoading()) {
    on<OrderBoardLoadRequested>(_onLoadRequested, transformer: restartable());
    on<OrderBoardRefreshRequested>(
      _onRefreshRequested,
      transformer: droppable(),
    );
    on<OrderBoardLoadMoreRequested>(
      _onLoadMoreRequested,
      transformer: droppable(),
    );
    on<OrderBoardFilterChanged>(_onFilterChanged, transformer: restartable());
    on<OrderBoardQueryChanged>(_onQueryChanged, transformer: restartable());
    on<OrderBoardOrderUpserted>(_onOrderUpserted);
    on<OrderBoardAlertDismissed>(_onAlertDismissed);
  }

  final OrderRepository _orderRepository;
  final int pageSize;

  Future<void> _onLoadRequested(
    OrderBoardLoadRequested event,
    Emitter<OrderBoardState> emit,
  ) async {
    await _loadFirstPage(
      emit,
      filter: state.filter,
      query: state.searchQuery,
      showLoading: true,
    );
  }

  Future<void> _onRefreshRequested(
    OrderBoardRefreshRequested event,
    Emitter<OrderBoardState> emit,
  ) async {
    final current = state;
    if (current is OrderBoardLoaded) {
      emit(current.copyWith(isRefreshing: true));
    }
    await _loadFirstPage(
      emit,
      filter: state.filter,
      query: state.searchQuery,
      showLoading: current is! OrderBoardLoaded,
    );
  }

  Future<void> _onFilterChanged(
    OrderBoardFilterChanged event,
    Emitter<OrderBoardState> emit,
  ) async {
    if (event.filter == state.filter && state is OrderBoardLoaded) return;
    await _loadFirstPage(
      emit,
      filter: event.filter,
      query: state.searchQuery,
      showLoading: true,
    );
  }

  Future<void> _onQueryChanged(
    OrderBoardQueryChanged event,
    Emitter<OrderBoardState> emit,
  ) async {
    final normalized = event.query.trim();
    if (normalized == state.searchQuery && state is OrderBoardLoaded) return;
    await _loadFirstPage(
      emit,
      filter: state.filter,
      query: normalized,
      showLoading: true,
    );
  }

  Future<void> _onLoadMoreRequested(
    OrderBoardLoadMoreRequested event,
    Emitter<OrderBoardState> emit,
  ) async {
    final current = state;
    if (current is! OrderBoardLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    final nextPage = current.page + 1;
    final pageResult = await _orderRepository.fetchOrders(
      status: current.filter.statusFilter,
      query: current.searchQuery,
      page: nextPage,
      pageSize: pageSize,
    );

    if (emit.isDone) return;

    switch (pageResult) {
      case Success<OrderPage>(:final value):
        final merged = List<Order>.from(current.orders);
        final existingIds = merged.map((o) => o.id).toSet();
        for (final item in value.items) {
          if (existingIds.add(item.id)) {
            merged.add(item);
          }
        }
        emit(
          current.copyWith(
            orders: merged,
            page: value.page,
            hasMore: value.hasMore,
            totalCount: value.totalCount,
            isLoadingMore: false,
          ),
        );
      case Err<OrderPage>():
        emit(current.copyWith(isLoadingMore: false));
    }
  }

  void _onOrderUpserted(
    OrderBoardOrderUpserted event,
    Emitter<OrderBoardState> emit,
  ) {
    final order = event.order;
    final matchesFilter = state.filter.statusFilter == null ||
        order.status == state.filter.statusFilter;
    final queryLower = state.searchQuery.toLowerCase();
    final matchesQuery = queryLower.isEmpty ||
        order.id.toLowerCase().contains(queryLower) ||
        order.customerName.toLowerCase().contains(queryLower);

    final current = state;
    if (current is OrderBoardEmpty && matchesFilter && matchesQuery) {
      emit(
        OrderBoardLoaded(
          orders: [order],
          stats: current.stats,
          filter: current.filter,
          searchQuery: current.searchQuery,
          page: 1,
          hasMore: false,
          totalCount: 1,
          incomingAlertOrder: event.isNewIncoming ? order : null,
        ),
      );
      return;
    }

    if (current is! OrderBoardLoaded) return;

    final updated = List<Order>.from(current.orders);
    final existingIdx = updated.indexWhere((o) => o.id == order.id);

    if (!matchesFilter || !matchesQuery) {
      if (existingIdx >= 0) {
        updated.removeAt(existingIdx);
      }
    } else if (existingIdx >= 0) {
      updated[existingIdx] = order;
    } else {
      updated.insert(0, order);
    }

    if (updated.isEmpty) {
      emit(
        OrderBoardEmpty(
          filter: current.filter,
          searchQuery: current.searchQuery,
          stats: current.stats,
        ),
      );
      return;
    }

    emit(
      current.copyWith(
        orders: updated,
        incomingAlertOrder: event.isNewIncoming ? order : null,
      ),
    );
  }

  void _onAlertDismissed(
    OrderBoardAlertDismissed event,
    Emitter<OrderBoardState> emit,
  ) {
    final current = state;
    if (current is OrderBoardLoaded && current.incomingAlertOrder != null) {
      emit(current.copyWith(clearIncomingAlert: true));
    }
  }

  Future<void> _loadFirstPage(
    Emitter<OrderBoardState> emit, {
    required OrderFilterTab filter,
    required String query,
    required bool showLoading,
  }) async {
    if (showLoading) {
      emit(
        OrderBoardLoading(
          filter: filter,
          searchQuery: query,
          stats: state.stats,
        ),
      );
    }

    // Fetch orders and shift KPIs concurrently so token refresh is exercised seamlessly.
    final results = await Future.wait<dynamic>([
      _orderRepository.fetchOrders(
        status: filter.statusFilter,
        query: query,
        page: 1,
        pageSize: pageSize,
      ),
      _orderRepository.fetchShiftStats(),
    ]);

    if (emit.isDone) return;

    final pageResult = results[0] as Result<OrderPage>;
    final statsResult = results[1] as Result<MerchantShiftStats>;
    final resolvedStats = statsResult.valueOrNull ?? state.stats;

    switch (pageResult) {
      case Success<OrderPage>(:final value):
        if (value.items.isEmpty) {
          emit(
            OrderBoardEmpty(
              filter: filter,
              searchQuery: query,
              stats: resolvedStats,
            ),
          );
        } else {
          emit(
            OrderBoardLoaded(
              orders: value.items,
              stats: resolvedStats,
              filter: filter,
              searchQuery: query,
              page: value.page,
              hasMore: value.hasMore,
              totalCount: value.totalCount,
            ),
          );
        }
      case Err<OrderPage>(:final failure):
        emit(
          OrderBoardError(
            message: failure.message,
            filter: filter,
            searchQuery: query,
            stats: resolvedStats,
          ),
        );
    }
  }
}
