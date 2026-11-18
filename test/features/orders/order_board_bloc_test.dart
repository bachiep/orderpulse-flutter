import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orderpulse_flutter/core/error/failures.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_board_bloc.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

Order _makeOrder(
  String id, {
  OrderStatus status = OrderStatus.newOrder,
  DateTime? createdAt,
}) {
  final ts = createdAt ?? DateTime.utc(2026, 11, 18, 8, 0);
  return Order(
    id: id,
    customerName: 'Customer $id',
    customerPhone: '0901 *** 000',
    items: const [
      OrderItem(name: 'Pho Bo', quantity: 1, unitPriceVnd: 65000),
    ],
    totalAmountVnd: 65000,
    status: status,
    createdAt: ts,
    updatedAt: ts,
  );
}

void main() {
  late _MockOrderRepository repository;

  const sampleStats = MerchantShiftStats(
    activeCount: 3,
    completedToday: 5,
    revenueTodayVnd: 750000,
    avgPrepMinutes: 10.5,
  );

  setUp(() {
    repository = _MockOrderRepository();
    when(() => repository.fetchShiftStats())
        .thenAnswer((_) async => const Success(sampleStats));
  });

  group('OrderBoardBloc', () {
    blocTest<OrderBoardBloc, OrderBoardState>(
      'emits [OrderBoardLoading, OrderBoardLoaded] and loads page 2 via LoadMore',
      build: () {
        when(
          () => repository.fetchOrders(
            status: any(named: 'status'),
            query: any(named: 'query'),
            page: 1,
            pageSize: 2,
          ),
        ).thenAnswer(
          (_) async => Success(
            OrderPage(
              items: [_makeOrder('ORD-1'), _makeOrder('ORD-2')],
              page: 1,
              pageSize: 2,
              hasMore: true,
              totalCount: 3,
            ),
          ),
        );
        when(
          () => repository.fetchOrders(
            status: any(named: 'status'),
            query: any(named: 'query'),
            page: 2,
            pageSize: 2,
          ),
        ).thenAnswer(
          (_) async => Success(
            OrderPage(
              items: [_makeOrder('ORD-3')],
              page: 2,
              pageSize: 2,
              hasMore: false,
              totalCount: 3,
            ),
          ),
        );
        return OrderBoardBloc(orderRepository: repository, pageSize: 2);
      },
      act: (bloc) async {
        bloc.add(const OrderBoardLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OrderBoardLoadMoreRequested());
      },
      expect: () => [
        const OrderBoardLoading(),
        OrderBoardLoaded(
          orders: [_makeOrder('ORD-1'), _makeOrder('ORD-2')],
          stats: sampleStats,
          filter: OrderFilterTab.all,
          searchQuery: '',
          page: 1,
          hasMore: true,
          totalCount: 3,
        ),
        OrderBoardLoaded(
          orders: [_makeOrder('ORD-1'), _makeOrder('ORD-2')],
          stats: sampleStats,
          filter: OrderFilterTab.all,
          searchQuery: '',
          page: 1,
          hasMore: true,
          totalCount: 3,
          isLoadingMore: true,
        ),
        OrderBoardLoaded(
          orders: [_makeOrder('ORD-1'), _makeOrder('ORD-2'), _makeOrder('ORD-3')],
          stats: sampleStats,
          filter: OrderFilterTab.all,
          searchQuery: '',
          page: 2,
          hasMore: false,
          totalCount: 3,
          isLoadingMore: false,
        ),
      ],
    );

    blocTest<OrderBoardBloc, OrderBoardState>(
      'emits OrderBoardEmpty when repository returns empty page',
      build: () {
        when(
          () => repository.fetchOrders(
            status: any(named: 'status'),
            query: any(named: 'query'),
            page: 1,
            pageSize: 8,
          ),
        ).thenAnswer(
          (_) async => const Success(
            OrderPage(
              items: [],
              page: 1,
              pageSize: 8,
              hasMore: false,
              totalCount: 0,
            ),
          ),
        );
        return OrderBoardBloc(orderRepository: repository);
      },
      act: (bloc) => bloc.add(const OrderBoardLoadRequested()),
      expect: () => const [
        OrderBoardLoading(),
        OrderBoardEmpty(
          filter: OrderFilterTab.all,
          searchQuery: '',
          stats: sampleStats,
        ),
      ],
    );

    blocTest<OrderBoardBloc, OrderBoardState>(
      'emits OrderBoardError when repository fails',
      build: () {
        when(
          () => repository.fetchOrders(
            status: any(named: 'status'),
            query: any(named: 'query'),
            page: 1,
            pageSize: 8,
          ),
        ).thenAnswer(
          (_) async => const Err(NetworkFailure('Connection timed out')),
        );
        return OrderBoardBloc(orderRepository: repository);
      },
      act: (bloc) => bloc.add(const OrderBoardLoadRequested()),
      expect: () => const [
        OrderBoardLoading(),
        OrderBoardError(
          message: 'Connection timed out',
          filter: OrderFilterTab.all,
          searchQuery: '',
          stats: sampleStats,
        ),
      ],
    );

    final fixedNow = DateTime.utc(2026, 11, 18, 8, 20);
    final healthyOrder = _makeOrder(
      'ORD-HEALTHY',
      createdAt: fixedNow.subtract(const Duration(minutes: 2)),
    );
    final overdueOrder = _makeOrder(
      'ORD-OVERDUE',
      status: OrderStatus.preparing,
      createdAt: fixedNow.subtract(const Duration(minutes: 19)),
    );

    blocTest<OrderBoardBloc, OrderBoardState>(
      'filters Urgent SLA orders and sorts by SLA urgency first without refetching',
      build: () {
        when(
          () => repository.fetchOrders(
            status: any(named: 'status'),
            query: any(named: 'query'),
            page: 1,
            pageSize: 8,
          ),
        ).thenAnswer(
          (_) async => Success(
            OrderPage(
              items: [healthyOrder, overdueOrder],
              page: 1,
              pageSize: 8,
              hasMore: false,
              totalCount: 2,
            ),
          ),
        );
        return OrderBoardBloc(
          orderRepository: repository,
          clock: FixedClock(fixedNow),
        );
      },
      act: (bloc) async {
        bloc.add(const OrderBoardLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OrderBoardSortModeChanged(OrderSortMode.slaUrgencyFirst));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OrderBoardUrgentFilterToggled());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OrderBoardUrgentFilterToggled());
      },
      expect: () => [
        const OrderBoardLoading(),
        OrderBoardLoaded(
          orders: [healthyOrder, overdueOrder],
          stats: sampleStats,
          filter: OrderFilterTab.all,
          searchQuery: '',
          page: 1,
          hasMore: false,
          totalCount: 2,
        ),
        OrderBoardLoaded(
          orders: [overdueOrder, healthyOrder],
          stats: sampleStats,
          filter: OrderFilterTab.all,
          searchQuery: '',
          sortMode: OrderSortMode.slaUrgencyFirst,
          page: 1,
          hasMore: false,
          totalCount: 2,
        ),
        OrderBoardLoaded(
          orders: [overdueOrder],
          stats: sampleStats,
          filter: OrderFilterTab.all,
          searchQuery: '',
          urgentOnly: true,
          sortMode: OrderSortMode.slaUrgencyFirst,
          page: 1,
          hasMore: false,
          totalCount: 2,
        ),
        OrderBoardLoaded(
          orders: [overdueOrder, healthyOrder],
          stats: sampleStats,
          filter: OrderFilterTab.all,
          searchQuery: '',
          urgentOnly: false,
          sortMode: OrderSortMode.slaUrgencyFirst,
          page: 1,
          hasMore: false,
          totalCount: 2,
        ),
      ],
    );
  });
}
