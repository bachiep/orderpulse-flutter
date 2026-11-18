import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orderpulse_flutter/core/error/failures.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/insights/domain/shift_insights.dart';
import 'package:orderpulse_flutter/features/insights/presentation/bloc/shift_insights_cubit.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

void main() {
  final now = DateTime.utc(2026, 11, 18, 10, 30);

  final sampleOrders = [
    Order(
      id: 'ORD-1',
      customerName: 'Customer 1',
      customerPhone: '0901 *** 001',
      items: const [
        OrderItem(name: 'Pho Bo Tai Nam', quantity: 3, unitPriceVnd: 72000),
        OrderItem(name: 'Ca Phe Sua Da', quantity: 2, unitPriceVnd: 32000),
      ],
      totalAmountVnd: 280000,
      status: OrderStatus.completed,
      createdAt: DateTime.utc(2026, 11, 18, 8, 10),
      updatedAt: DateTime.utc(2026, 11, 18, 8, 22),
      readyAt: DateTime.utc(2026, 11, 18, 8, 20), // 10 min prep -> on-time
      completedAt: DateTime.utc(2026, 11, 18, 8, 22),
    ),
    Order(
      id: 'ORD-2',
      customerName: 'Customer 2',
      customerPhone: '0901 *** 002',
      items: const [
        OrderItem(name: 'Pho Bo Tai Nam', quantity: 2, unitPriceVnd: 72000),
        OrderItem(name: 'Com Tam Suon', quantity: 4, unitPriceVnd: 58000),
      ],
      totalAmountVnd: 376000,
      status: OrderStatus.completed,
      createdAt: DateTime.utc(2026, 11, 18, 9, 15),
      updatedAt: DateTime.utc(2026, 11, 18, 9, 36),
      readyAt: DateTime.utc(2026, 11, 18, 9, 35), // 20 min prep -> late (>15m)
      completedAt: DateTime.utc(2026, 11, 18, 9, 36),
    ),
    Order(
      id: 'ORD-3',
      customerName: 'Customer 3',
      customerPhone: '0901 *** 003',
      items: const [
        OrderItem(name: 'Bun Bo Hue', quantity: 2, unitPriceVnd: 68000),
        OrderItem(name: 'Tra Dao', quantity: 1, unitPriceVnd: 38000),
        OrderItem(name: 'Quay Nong', quantity: 1, unitPriceVnd: 18000),
      ],
      totalAmountVnd: 192000,
      status: OrderStatus.preparing,
      createdAt: DateTime.utc(2026, 11, 18, 10, 22), // 8m elapsed -> on-time
      updatedAt: DateTime.utc(2026, 11, 18, 10, 24),
    ),
    Order(
      id: 'ORD-4',
      customerName: 'Customer 4',
      customerPhone: '0901 *** 004',
      items: const [
        OrderItem(name: 'Rejected Hotpot', quantity: 10, unitPriceVnd: 250000),
      ],
      totalAmountVnd: 2500000,
      status: OrderStatus.rejected,
      createdAt: DateTime.utc(2026, 11, 18, 9, 40),
      updatedAt: DateTime.utc(2026, 11, 18, 9, 42),
      rejectionReason: 'Out of stock',
    ),
  ];

  group('ShiftInsightsCalculator', () {
    test('computes KPIs, hourly buckets, status mix, and ranked top 5 dishes', () {
      final insights = ShiftInsightsCalculator.compute(sampleOrders, now);

      expect(insights.totalOrders, 4);
      expect(insights.completedOrders, 2);
      expect(insights.grossRevenueVnd, 280000 + 376000);
      expect(insights.avgPrepMinutes, closeTo(15.0, 0.01)); // (10 + 20) / 2
      // 3 SLA-evaluated non-rejected orders: ORD-1 on-time, ORD-2 late, ORD-3 on-time => 66.7%
      expect(insights.onTimeSlaPercent, closeTo(66.66, 0.1));

      expect(insights.hourlyBuckets.map((b) => b.hour), [8, 9, 10]);
      expect(insights.hourlyBuckets[0].completedCount, 1);
      expect(insights.hourlyBuckets[1].totalCount, 2);
      expect(insights.hourlyBuckets[2].activeCount, 1);

      final completedSlice = insights.statusMix
          .firstWhere((s) => s.status == OrderStatus.completed);
      expect(completedSlice.count, 2);
      expect(completedSlice.share, closeTo(0.5, 0.001));

      // Top 5 excludes rejected orders ('Rejected Hotpot' 10x must not appear).
      expect(insights.topDishes, hasLength(5));
      expect(insights.topDishes[0].dishName, 'Pho Bo Tai Nam');
      expect(insights.topDishes[0].quantitySold, 5);
      expect(insights.topDishes[0].revenueVnd, 360000);
      expect(insights.topDishes[1].dishName, 'Com Tam Suon');
      expect(insights.topDishes[1].quantitySold, 4);
      expect(
        insights.topDishes.any((d) => d.dishName == 'Rejected Hotpot'),
        isFalse,
      );
    });

    test('handles empty order list safely', () {
      final empty = ShiftInsightsCalculator.compute(const [], now);
      expect(empty.totalOrders, 0);
      expect(empty.completedOrders, 0);
      expect(empty.grossRevenueVnd, 0);
      expect(empty.avgPrepMinutes, 0.0);
      expect(empty.onTimeSlaPercent, 0.0);
      expect(empty.hourlyBuckets, isEmpty);
      expect(empty.topDishes, isEmpty);
    });
  });

  group('ShiftInsightsCubit', () {
    late _MockOrderRepository repository;

    setUp(() {
      repository = _MockOrderRepository();
    });

    blocTest<ShiftInsightsCubit, ShiftInsightsState>(
      'loads shift orders and supports live upsertOrder',
      build: () {
        when(
          () => repository.fetchOrders(
            status: any(named: 'status'),
            query: any(named: 'query'),
            page: 1,
            pageSize: 100,
          ),
        ).thenAnswer(
          (_) async => Success(
            OrderPage(
              items: [sampleOrders.first],
              page: 1,
              pageSize: 100,
              hasMore: false,
              totalCount: 1,
            ),
          ),
        );
        return ShiftInsightsCubit(orderRepository: repository);
      },
      act: (cubit) async {
        await cubit.loadShiftOrders();
        cubit.upsertOrder(sampleOrders[2]);
      },
      expect: () => [
        const ShiftInsightsState(isLoading: true),
        ShiftInsightsState(orders: [sampleOrders.first], isLoading: false),
        ShiftInsightsState(
          orders: [sampleOrders[2], sampleOrders.first],
          isLoading: false,
        ),
      ],
    );

    blocTest<ShiftInsightsCubit, ShiftInsightsState>(
      'emits errorMessage when shift orders load fails',
      build: () {
        when(
          () => repository.fetchOrders(
            status: any(named: 'status'),
            query: any(named: 'query'),
            page: 1,
            pageSize: 100,
          ),
        ).thenAnswer(
          (_) async => const Err(NetworkFailure('Timeout')),
        );
        return ShiftInsightsCubit(orderRepository: repository);
      },
      act: (cubit) => cubit.loadShiftOrders(),
      expect: () => const [
        ShiftInsightsState(isLoading: true),
        ShiftInsightsState(isLoading: false, errorMessage: 'Timeout'),
      ],
    );
  });
}
