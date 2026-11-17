import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orderpulse_flutter/core/error/failures.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/dispatch/domain/order_state_machine.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/bloc/order_action_bloc.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

Order _orderWithStatus(OrderStatus status) {
  final ts = DateTime.utc(2026, 11, 18, 9, 0);
  return Order(
    id: 'ORD-1028',
    customerName: 'Tran Minh Anh',
    customerPhone: '0912 *** 401',
    items: const [
      OrderItem(name: 'Com Tam', quantity: 1, unitPriceVnd: 58000),
    ],
    totalAmountVnd: 58000,
    status: status,
    createdAt: ts,
    updatedAt: ts,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(OrderStatus.newOrder);
  });

  group('OrderStateMachine', () {
    test('permits linear workflow and NEW -> REJECTED with reason', () {
      expect(
        OrderStateMachine.validateTransition(
          OrderStatus.newOrder,
          OrderStatus.preparing,
        ).isSuccess,
        isTrue,
      );
      expect(
        OrderStateMachine.validateTransition(
          OrderStatus.preparing,
          OrderStatus.ready,
        ).isSuccess,
        isTrue,
      );
      expect(
        OrderStateMachine.validateTransition(
          OrderStatus.ready,
          OrderStatus.completed,
        ).isSuccess,
        isTrue,
      );
      expect(
        OrderStateMachine.validateTransition(
          OrderStatus.newOrder,
          OrderStatus.rejected,
          reason: 'Out of stock',
        ).isSuccess,
        isTrue,
      );
    });

    test('rejects invalid jumps and empty rejection reasons', () {
      expect(
        OrderStateMachine.validateTransition(
          OrderStatus.newOrder,
          OrderStatus.ready,
        ).isErr,
        isTrue,
      );
      expect(
        OrderStateMachine.validateTransition(
          OrderStatus.newOrder,
          OrderStatus.completed,
        ).isErr,
        isTrue,
      );
      expect(
        OrderStateMachine.validateTransition(
          OrderStatus.preparing,
          OrderStatus.rejected,
          reason: 'Late',
        ).isErr,
        isTrue,
      );
      expect(
        OrderStateMachine.validateTransition(
          OrderStatus.completed,
          OrderStatus.preparing,
        ).isErr,
        isTrue,
      );
      expect(
        OrderStateMachine.validateTransition(
          OrderStatus.newOrder,
          OrderStatus.rejected,
          reason: '   ',
        ).failureOrNull,
        isA<ValidationFailure>(),
      );
    });
  });

  group('OrderActionBloc (droppable concurrency)', () {
    late _MockOrderRepository repository;

    setUp(() {
      repository = _MockOrderRepository();
    });

    blocTest<OrderActionBloc, OrderActionState>(
      'droppable() drops rapid duplicate double-taps while transition is in flight',
      build: () {
        final newOrder = _orderWithStatus(OrderStatus.newOrder);
        final preparingOrder = newOrder.copyWith(status: OrderStatus.preparing);
        when(
          () => repository.transitionOrder(
            orderId: 'ORD-1028',
            targetStatus: OrderStatus.preparing,
            rejectionReason: null,
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return Success(preparingOrder);
        });
        return OrderActionBloc(orderRepository: repository);
      },
      act: (bloc) async {
        final order = _orderWithStatus(OrderStatus.newOrder);
        bloc.add(
          OrderTransitionRequested(
            order: order,
            targetStatus: OrderStatus.preparing,
          ),
        );
        bloc.add(
          OrderTransitionRequested(
            order: order,
            targetStatus: OrderStatus.preparing,
          ),
        );
        bloc.add(
          OrderTransitionRequested(
            order: order,
            targetStatus: OrderStatus.preparing,
          ),
        );
      },
      wait: const Duration(milliseconds: 80),
      expect: () => [
        const OrderActionInProgress(
          orderId: 'ORD-1028',
          targetStatus: OrderStatus.preparing,
        ),
        OrderActionSuccess(
          _orderWithStatus(OrderStatus.newOrder)
              .copyWith(status: OrderStatus.preparing),
        ),
      ],
      verify: (_) {
        verify(
          () => repository.transitionOrder(
            orderId: 'ORD-1028',
            targetStatus: OrderStatus.preparing,
            rejectionReason: null,
          ),
        ).called(1);
      },
    );

    blocTest<OrderActionBloc, OrderActionState>(
      'emits OrderActionFailure without calling repository on invalid transition',
      build: () => OrderActionBloc(orderRepository: repository),
      act: (bloc) => bloc.add(
        OrderTransitionRequested(
          order: _orderWithStatus(OrderStatus.newOrder),
          targetStatus: OrderStatus.completed,
        ),
      ),
      expect: () => const [
        OrderActionFailure(
          orderId: 'ORD-1028',
          message: 'Cannot transition order from New to Completed.',
        ),
      ],
      verify: (_) => verifyNever(
        () => repository.transitionOrder(
          orderId: any(named: 'orderId'),
          targetStatus: any(named: 'targetStatus'),
          rejectionReason: any(named: 'rejectionReason'),
        ),
      ),
    );
  });
}
