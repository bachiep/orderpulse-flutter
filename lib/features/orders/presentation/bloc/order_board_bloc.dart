import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_sla.dart';

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

final class OrderBoardUrgentFilterToggled extends OrderBoardEvent {
  const OrderBoardUrgentFilterToggled();
}

final class OrderBoardUrgentFilterChanged extends OrderBoardEvent {
  const OrderBoardUrgentFilterChanged(this.urgentOnly);

  final bool urgentOnly;

  @override
  List<Object?> get props => [urgentOnly];
}

final class OrderBoardSortModeChanged extends OrderBoardEvent {
  const OrderBoardSortModeChanged(this.sortMode);

  final OrderSortMode sortMode;

  @override
  List<Object?> get props => [sortMode];
}

final class OrderBoardOrderUpserted extends OrderBoardEvent {
  const OrderBoardOrderUpserted(this.order, {this.isNewIncoming = false});

  final Order order;
  final bool isNewIncoming;

  @override
  List<Object?> get props => [order, isNewIncoming];
}

final class OrderBoardOrderCancelled extends OrderBoardEvent {
  const OrderBoardOrderCancelled({
    required this.orderId,
    required this.reason,
  });

  final String orderId;
  final String reason;

  @override
  List<Object?> get props => [orderId, reason];
}

final class OrderBoardRiderAssigned extends OrderBoardEvent {
  const OrderBoardRiderAssigned({
    required this.orderId,
    required this.riderName,
    required this.riderPlate,
  });

  final String orderId;
  final String riderName;
  final String riderPlate;

  @override
  List<Object?> get props => [orderId, riderName, riderPlate];
}

final class OrderBoardAlertDismissed extends OrderBoardEvent {
  const OrderBoardAlertDismissed();
}

sealed class OrderBoardState extends Equatable {
  const OrderBoardState({
    required this.filter,
    required this.searchQuery,
    this.urgentOnly = false,
    this.sortMode = OrderSortMode.newestFirst,
    this.stats,
  });

  final OrderFilterTab filter;
  final String searchQuery;
  final bool urgentOnly;
  final OrderSortMode sortMode;
  final MerchantShiftStats? stats;

  @override
  List<Object?> get props => [filter, searchQuery, urgentOnly, sortMode, stats];
}

final class OrderBoardLoading extends OrderBoardState {
  const OrderBoardLoading({
    super.filter = OrderFilterTab.all,
    super.searchQuery = '',
    super.urgentOnly = false,
    super.sortMode = OrderSortMode.newestFirst,
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
    super.urgentOnly = false,
    super.sortMode = OrderSortMode.newestFirst,
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
    bool? urgentOnly,
    OrderSortMode? sortMode,
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
      urgentOnly: urgentOnly ?? this.urgentOnly,
      sortMode: sortMode ?? this.sortMode,
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
    super.urgentOnly = false,
    super.sortMode = OrderSortMode.newestFirst,
    super.stats,
  });
}

final class OrderBoardError extends OrderBoardState {
  const OrderBoardError({
    required this.message,
    required super.filter,
    required super.searchQuery,
    super.urgentOnly = false,
    super.sortMode = OrderSortMode.newestFirst,
    super.stats,
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

/// Manages paginated order fetching, SLA filtering/sorting, search reloads, and live list updates.
class OrderBoardBloc extends Bloc<OrderBoardEvent, OrderBoardState> {
  OrderBoardBloc({
    required OrderRepository orderRepository,
    AppClock clock = const SystemClock(),
    this.pageSize = 8,
  })  : _orderRepository = orderRepository,
        _clock = clock,
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
    on<OrderBoardUrgentFilterToggled>(_onUrgentFilterToggled);
    on<OrderBoardUrgentFilterChanged>(_onUrgentFilterChanged);
    on<OrderBoardSortModeChanged>(_onSortModeChanged);
    on<OrderBoardOrderUpserted>(_onOrderUpserted);
    on<OrderBoardOrderCancelled>(_onOrderCancelled);
    on<OrderBoardRiderAssigned>(_onRiderAssigned);
    on<OrderBoardAlertDismissed>(_onAlertDismissed);
  }

  final OrderRepository _orderRepository;
  final AppClock _clock;
  final int pageSize;

  final List<Order> _rawOrders = [];
  int _page = 1;
  bool _hasMore = false;
  int _totalCount = 0;

  Future<void> _onLoadRequested(
    OrderBoardLoadRequested event,
    Emitter<OrderBoardState> emit,
  ) async {
    await _loadFirstPage(
      emit,
      filter: state.filter,
      query: state.searchQuery,
      urgentOnly: state.urgentOnly,
      sortMode: state.sortMode,
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
      urgentOnly: state.urgentOnly,
      sortMode: state.sortMode,
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
      urgentOnly: state.urgentOnly,
      sortMode: state.sortMode,
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
      urgentOnly: state.urgentOnly,
      sortMode: state.sortMode,
      showLoading: true,
    );
  }

  void _onUrgentFilterToggled(
    OrderBoardUrgentFilterToggled event,
    Emitter<OrderBoardState> emit,
  ) {
    _applyClientViewChange(
      emit,
      urgentOnly: !state.urgentOnly,
      sortMode: state.sortMode,
    );
  }

  void _onUrgentFilterChanged(
    OrderBoardUrgentFilterChanged event,
    Emitter<OrderBoardState> emit,
  ) {
    if (event.urgentOnly == state.urgentOnly) return;
    _applyClientViewChange(
      emit,
      urgentOnly: event.urgentOnly,
      sortMode: state.sortMode,
    );
  }

  void _onSortModeChanged(
    OrderBoardSortModeChanged event,
    Emitter<OrderBoardState> emit,
  ) {
    if (event.sortMode == state.sortMode) return;
    _applyClientViewChange(
      emit,
      urgentOnly: state.urgentOnly,
      sortMode: event.sortMode,
    );
  }

  void _applyClientViewChange(
    Emitter<OrderBoardState> emit, {
    required bool urgentOnly,
    required OrderSortMode sortMode,
  }) {
    final current = state;
    if (current is OrderBoardLoading) {
      emit(
        OrderBoardLoading(
          filter: current.filter,
          searchQuery: current.searchQuery,
          urgentOnly: urgentOnly,
          sortMode: sortMode,
          stats: current.stats,
        ),
      );
      return;
    }
    if (current is OrderBoardError) {
      emit(
        OrderBoardError(
          message: current.message,
          filter: current.filter,
          searchQuery: current.searchQuery,
          urgentOnly: urgentOnly,
          sortMode: sortMode,
          stats: current.stats,
        ),
      );
      return;
    }

    if (_rawOrders.isEmpty && current is OrderBoardLoaded) {
      _rawOrders
        ..clear()
        ..addAll(current.orders);
      _page = current.page;
      _hasMore = current.hasMore;
      _totalCount = current.totalCount;
    }

    _emitFromRawOrders(
      emit,
      filter: current.filter,
      searchQuery: current.searchQuery,
      urgentOnly: urgentOnly,
      sortMode: sortMode,
      stats: current.stats,
      incomingAlertOrder:
          current is OrderBoardLoaded ? current.incomingAlertOrder : null,
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
        if (_rawOrders.isEmpty) {
          _rawOrders.addAll(current.orders);
        }
        final existingIds = _rawOrders.map((o) => o.id).toSet();
        for (final item in value.items) {
          if (existingIds.add(item.id)) {
            _rawOrders.add(item);
          }
        }
        _page = value.page;
        _hasMore = value.hasMore;
        _totalCount = value.totalCount;

        final visible = OrderSlaEvaluator.applyBoardView(
          _rawOrders,
          now: _clock.now(),
          urgentOnly: current.urgentOnly,
          sortMode: current.sortMode,
        );
        emit(
          current.copyWith(
            orders: visible,
            page: _page,
            hasMore: _hasMore,
            totalCount: _totalCount,
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
    if (current is! OrderBoardLoaded && current is! OrderBoardEmpty) {
      return;
    }

    if (_rawOrders.isEmpty && current is OrderBoardLoaded) {
      _rawOrders.addAll(current.orders);
      _page = current.page;
      _hasMore = current.hasMore;
      _totalCount = current.totalCount;
    }

    final existingIdx = _rawOrders.indexWhere((o) => o.id == order.id);
    if (!matchesFilter || !matchesQuery) {
      if (existingIdx >= 0) {
        _rawOrders.removeAt(existingIdx);
      }
    } else if (existingIdx >= 0) {
      _rawOrders[existingIdx] = order;
    } else {
      _rawOrders.insert(0, order);
      if (current is OrderBoardEmpty) {
        _page = 1;
        _hasMore = false;
        _totalCount = 1;
      } else {
        _totalCount += 1;
      }
    }

    _emitFromRawOrders(
      emit,
      filter: current.filter,
      searchQuery: current.searchQuery,
      urgentOnly: current.urgentOnly,
      sortMode: current.sortMode,
      stats: current.stats,
      incomingAlertOrder: event.isNewIncoming
          ? order
          : (current is OrderBoardLoaded ? current.incomingAlertOrder : null),
    );
  }

  void _onOrderCancelled(
    OrderBoardOrderCancelled event,
    Emitter<OrderBoardState> emit,
  ) {
    final current = state;
    if (current is! OrderBoardLoaded) return;
    final source = _rawOrders.isNotEmpty ? _rawOrders : current.orders;
    final idx = source.indexWhere((o) => o.id == event.orderId);
    if (idx < 0) return;

    final updatedOrder = source[idx].copyWith(
      status: OrderStatus.rejected,
      rejectionReason: event.reason,
      updatedAt: _clock.now(),
    );
    _onOrderUpserted(OrderBoardOrderUpserted(updatedOrder), emit);
  }

  void _onRiderAssigned(
    OrderBoardRiderAssigned event,
    Emitter<OrderBoardState> emit,
  ) {
    final current = state;
    if (current is! OrderBoardLoaded) return;
    final source = _rawOrders.isNotEmpty ? _rawOrders : current.orders;
    final idx = source.indexWhere((o) => o.id == event.orderId);
    if (idx < 0) return;

    final updatedOrder = source[idx].copyWith(
      riderName: event.riderName,
      riderPlate: event.riderPlate,
      updatedAt: _clock.now(),
    );
    _onOrderUpserted(OrderBoardOrderUpserted(updatedOrder), emit);
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
    required bool urgentOnly,
    required OrderSortMode sortMode,
    required bool showLoading,
  }) async {
    if (showLoading) {
      emit(
        OrderBoardLoading(
          filter: filter,
          searchQuery: query,
          urgentOnly: urgentOnly,
          sortMode: sortMode,
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
        _rawOrders
          ..clear()
          ..addAll(value.items);
        _page = value.page;
        _hasMore = value.hasMore;
        _totalCount = value.totalCount;

        _emitFromRawOrders(
          emit,
          filter: filter,
          searchQuery: query,
          urgentOnly: urgentOnly,
          sortMode: sortMode,
          stats: resolvedStats,
        );
      case Err<OrderPage>(:final failure):
        emit(
          OrderBoardError(
            message: failure.message,
            filter: filter,
            searchQuery: query,
            urgentOnly: urgentOnly,
            sortMode: sortMode,
            stats: resolvedStats,
          ),
        );
    }
  }

  void _emitFromRawOrders(
    Emitter<OrderBoardState> emit, {
    required OrderFilterTab filter,
    required String searchQuery,
    required bool urgentOnly,
    required OrderSortMode sortMode,
    MerchantShiftStats? stats,
    Order? incomingAlertOrder,
  }) {
    final visible = OrderSlaEvaluator.applyBoardView(
      _rawOrders,
      now: _clock.now(),
      urgentOnly: urgentOnly,
      sortMode: sortMode,
    );

    if (visible.isEmpty) {
      emit(
        OrderBoardEmpty(
          filter: filter,
          searchQuery: searchQuery,
          urgentOnly: urgentOnly,
          sortMode: sortMode,
          stats: stats,
        ),
      );
      return;
    }

    emit(
      OrderBoardLoaded(
        orders: visible,
        stats: stats,
        filter: filter,
        searchQuery: searchQuery,
        urgentOnly: urgentOnly,
        sortMode: sortMode,
        page: _page,
        hasMore: _hasMore,
        totalCount: _totalCount,
        incomingAlertOrder: incomingAlertOrder,
      ),
    );
  }
}
