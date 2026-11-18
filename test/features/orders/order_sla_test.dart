import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_sla.dart';

void main() {
  Order buildOrder({
    required DateTime createdAt,
    OrderStatus status = OrderStatus.newOrder,
    int targetPrepMinutes = 15,
  }) {
    return Order(
      id: 'ORD-5001',
      customerName: 'Test Customer',
      customerPhone: '0901 *** 111',
      items: const [
        OrderItem(name: 'Pho Bo', quantity: 1, unitPriceVnd: 65000),
      ],
      totalAmountVnd: 65000,
      status: status,
      createdAt: createdAt,
      updatedAt: createdAt,
      targetPrepMinutes: targetPrepMinutes,
    );
  }

  group('OrderSlaEvaluator (AppClock-driven)', () {
    test('transitions healthy -> warning -> overdue as FixedClock advances', () {
      final createdAt = DateTime.utc(2026, 11, 18, 9, 0, 0);
      final clock = FixedClock(createdAt.add(const Duration(minutes: 4)));
      final order = buildOrder(createdAt: createdAt);

      final healthy = OrderSlaEvaluator.evaluate(order, clock.now());
      expect(healthy.urgency, SlaUrgency.healthy);
      expect(healthy.label, '11m left');
      expect(healthy.urgency.isUrgent, isFalse);

      clock.advance(const Duration(minutes: 8)); // 12m elapsed -> 3m left
      final warning = OrderSlaEvaluator.evaluate(order, clock.now());
      expect(warning.urgency, SlaUrgency.warning);
      expect(warning.label, '3m left');
      expect(warning.urgency.isUrgent, isTrue);

      clock.advance(const Duration(minutes: 7)); // 19m elapsed -> +4m OVERDUE
      final overdue = OrderSlaEvaluator.evaluate(order, clock.now());
      expect(overdue.urgency, SlaUrgency.overdue);
      expect(overdue.label, '+4m OVERDUE');
      expect(overdue.urgency.isUrgent, isTrue);
    });

    test('evaluates healthy -> warning exact 5m boundary and sub-minute overdue', () {
      final createdAt = DateTime.utc(2026, 11, 18, 9, 0, 0);
      final order = buildOrder(createdAt: createdAt);

      final atBoundary = OrderSlaEvaluator.evaluate(
        order,
        createdAt.add(const Duration(minutes: 10)),
      );
      expect(atBoundary.urgency, SlaUrgency.warning);
      expect(atBoundary.label, '5m left');

      final justHealthy = OrderSlaEvaluator.evaluate(
        order,
        createdAt.add(const Duration(minutes: 9, seconds: 59)),
      );
      expect(justHealthy.urgency, SlaUrgency.healthy);
      expect(justHealthy.label, '6m left');

      final justOverdue = OrderSlaEvaluator.evaluate(
        order,
        createdAt.add(const Duration(minutes: 15, seconds: 1)),
      );
      expect(justOverdue.urgency, SlaUrgency.overdue);
      expect(justOverdue.label, '+1m OVERDUE');
    });

    test('returns SlaUrgency.none for completed and rejected terminal orders', () {
      final createdAt = DateTime.utc(2026, 11, 18, 9, 0, 0);
      final now = createdAt.add(const Duration(minutes: 30));

      final completed = buildOrder(
        createdAt: createdAt,
        status: OrderStatus.completed,
      );
      final rejected = buildOrder(
        createdAt: createdAt,
        status: OrderStatus.rejected,
      );

      expect(
        OrderSlaEvaluator.evaluate(completed, now).urgency,
        SlaUrgency.none,
      );
      expect(
        OrderSlaEvaluator.evaluate(rejected, now).urgency,
        SlaUrgency.none,
      );
    });

    test('applyBoardView filters urgent orders and sorts overdue tickets first', () {
      final now = DateTime.utc(2026, 11, 18, 9, 20);
      final healthy = buildOrder(
        createdAt: now.subtract(const Duration(minutes: 2)), // 13m left
      ).copyWith(updatedAt: now);
      final healthyOrder = Order(
        id: 'ORD-HEALTHY',
        customerName: 'Healthy',
        customerPhone: '0901',
        items: healthy.items,
        totalAmountVnd: 65000,
        status: OrderStatus.newOrder,
        createdAt: now.subtract(const Duration(minutes: 2)),
        updatedAt: now,
      );
      final warningOrder = Order(
        id: 'ORD-WARNING',
        customerName: 'Warning',
        customerPhone: '0901',
        items: healthy.items,
        totalAmountVnd: 65000,
        status: OrderStatus.newOrder,
        createdAt: now.subtract(const Duration(minutes: 12)), // 3m left
        updatedAt: now,
      );
      final overdueOrder = Order(
        id: 'ORD-OVERDUE',
        customerName: 'Overdue',
        customerPhone: '0901',
        items: healthy.items,
        totalAmountVnd: 65000,
        status: OrderStatus.preparing,
        createdAt: now.subtract(const Duration(minutes: 19)), // +4m OVERDUE
        updatedAt: now,
      );
      final completedOrder = Order(
        id: 'ORD-DONE',
        customerName: 'Done',
        customerPhone: '0901',
        items: healthy.items,
        totalAmountVnd: 65000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 30)),
        updatedAt: now,
      );

      final source = [healthyOrder, completedOrder, warningOrder, overdueOrder];

      final urgentOnly = OrderSlaEvaluator.applyBoardView(
        source,
        now: now,
        urgentOnly: true,
        sortMode: OrderSortMode.slaUrgencyFirst,
      );
      expect(urgentOnly.map((o) => o.id).toList(), [
        'ORD-OVERDUE',
        'ORD-WARNING',
      ]);

      final sortedAll = OrderSlaEvaluator.applyBoardView(
        source,
        now: now,
        urgentOnly: false,
        sortMode: OrderSortMode.slaUrgencyFirst,
      );
      expect(sortedAll.map((o) => o.id).toList(), [
        'ORD-OVERDUE',
        'ORD-WARNING',
        'ORD-HEALTHY',
        'ORD-DONE',
      ]);
    });
  });
}
