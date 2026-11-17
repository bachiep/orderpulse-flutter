import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/realtime/data/demo_order_realtime_source.dart';
import 'package:orderpulse_flutter/features/realtime/data/order_realtime_event_dto.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_event.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_source.dart';
import 'package:orderpulse_flutter/features/realtime/presentation/bloc/order_stream_bloc.dart';

class _ScriptedRealtimeDataSource implements OrderRealtimeDataSource {
  _ScriptedRealtimeDataSource(this._handlers);

  final List<Future<Stream<OrderRealtimeEvent>> Function()> _handlers;
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<Stream<OrderRealtimeEvent>> connect() async {
    final idx = connectCalls < _handlers.length
        ? connectCalls
        : _handlers.length - 1;
    connectCalls += 1;
    return _handlers[idx]();
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
  }
}

void main() {
  final fixedTime = DateTime.utc(2026, 11, 18, 10, 0);
  final sampleOrder = Order(
    id: 'ORD-1099',
    customerName: 'Nguyen Van A',
    customerPhone: '0901 *** 999',
    items: const [
      OrderItem(name: 'Bun Cha', quantity: 1, unitPriceVnd: 65000),
    ],
    totalAmountVnd: 65000,
    status: OrderStatus.newOrder,
    createdAt: fixedTime,
    updatedAt: fixedTime,
  );

  group('OrderRealtimeEventDto', () {
    test('parses ORDER_CREATED, ORDER_CANCELLED, RIDER_ASSIGNED and ignores heartbeats', () {
      final created = OrderRealtimeEventDto.tryParse(
        '{"type":"ORDER_CREATED","payload":{"id":"ORD-99","customerName":"Minh","customerPhone":"","items":[],"totalAmountVnd":50000,"status":"NEW","createdAt":"2026-11-18T10:00:00Z","updatedAt":"2026-11-18T10:00:00Z"}}',
      );
      final cancelled = OrderRealtimeEventDto.tryParse({
        'type': 'ORDER_CANCELLED',
        'payload': {'orderId': 'ORD-99', 'reason': 'Customer changed mind'},
      });
      final rider = OrderRealtimeEventDto.tryParse({
        'type': 'RIDER_ASSIGNED',
        'payload': {
          'orderId': 'ORD-99',
          'riderName': 'Tran Van B',
          'riderPlate': '59-X1 123.45',
        },
      });
      final ping = OrderRealtimeEventDto.tryParse('{"type":"PING"}');
      final bad = OrderRealtimeEventDto.tryParse('not-json');

      expect(created, isA<OrderCreatedEvent>());
      expect(cancelled, isA<OrderCancelledEvent>());
      expect(rider, isA<RiderAssignedEvent>());
      expect(ping, isNull);
      expect(bad, isNull);
    });
  });

  group('OrderStreamBloc', () {
    test('computes bounded exponential backoff 1s -> 2s -> 4s -> 8s -> max 16s', () {
      final source = DemoOrderRealtimeDataSource();
      final bloc = OrderStreamBloc(dataSource: source);

      expect(bloc.backoffForAttempt(1), const Duration(seconds: 1));
      expect(bloc.backoffForAttempt(2), const Duration(seconds: 2));
      expect(bloc.backoffForAttempt(3), const Duration(seconds: 4));
      expect(bloc.backoffForAttempt(4), const Duration(seconds: 8));
      expect(bloc.backoffForAttempt(5), const Duration(seconds: 16));
      expect(bloc.backoffForAttempt(6), const Duration(seconds: 16));
      expect(bloc.backoffForAttempt(10), const Duration(seconds: 16));

      bloc.close();
    });

    test(
      'transitions Live -> Reconnecting (backoff) -> Live on drop and cleans timers on close()',
      () async {
        final source = DemoOrderRealtimeDataSource();
        final bloc = OrderStreamBloc(
          dataSource: source,
          clock: FixedClock(fixedTime),
          initialBackoff: const Duration(milliseconds: 25),
          maxBackoff: const Duration(milliseconds: 100),
        );

        final emitted = <OrderStreamState>[];
        final sub = bloc.stream.listen(emitted.add);

        bloc.add(const OrderStreamConnectRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));

        source.emitOrderCreated(sampleOrder);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Drop stream -> enters Reconnecting(attempt: 1) then auto-reconnects to Live
        source.simulateConnectionDrop(stayOffline: false);
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(
          emitted,
          containsAllInOrder([
            const OrderStreamConnecting(),
            const OrderStreamLive(receivedCount: 0),
            OrderStreamLive(
              receivedCount: 1,
              lastEventAt: fixedTime,
              latestEvent: OrderCreatedEvent(sampleOrder),
            ),
            const OrderStreamReconnecting(
              attempt: 1,
              nextRetryDelay: Duration(milliseconds: 25),
            ),
            OrderStreamLive(receivedCount: 1, lastEventAt: fixedTime),
          ]),
        );

        await sub.cancel();
        await bloc.close();
        expect(bloc.isClosed, isTrue);
      },
    );

    test(
      'escalates bounded exponential backoff across consecutive failed connects and stops on close()',
      () async {
        final controller = StreamController<OrderRealtimeEvent>.broadcast();
        final scripted = _ScriptedRealtimeDataSource([
          () async => throw StateError('Initial outage 1'),
          () async => throw StateError('Outage 2'),
          () async => controller.stream,
        ]);

        final bloc = OrderStreamBloc(
          dataSource: scripted,
          clock: FixedClock(fixedTime),
          initialBackoff: const Duration(milliseconds: 20),
          maxBackoff: const Duration(milliseconds: 40),
        );

        final emitted = <OrderStreamState>[];
        final sub = bloc.stream.listen(emitted.add);

        bloc.add(const OrderStreamConnectRequested());
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(
          emitted,
          equals([
            const OrderStreamConnecting(),
            const OrderStreamReconnecting(
              attempt: 1,
              nextRetryDelay: Duration(milliseconds: 20),
            ),
            const OrderStreamReconnecting(
              attempt: 2,
              nextRetryDelay: Duration(milliseconds: 40),
            ),
            const OrderStreamLive(receivedCount: 0),
          ]),
        );

        await sub.cancel();
        await bloc.close();
        expect(scripted.disconnectCalls, greaterThanOrEqualTo(1));
        await controller.close();
      },
    );
  });
}
