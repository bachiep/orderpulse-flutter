import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/bloc/order_action_bloc.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/pages/order_detail_page.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

class _MockOrderActionBloc
    extends MockBloc<OrderActionEvent, OrderActionState>
    implements OrderActionBloc {}

void main() {
  late _MockOrderActionBloc actionBloc;
  final fixedClock = FixedClock(DateTime.utc(2026, 11, 18, 9, 10));

  final newOrder = Order(
    id: 'ORD-1028',
    customerName: 'Tran Minh Anh',
    customerPhone: '0912 *** 401',
    items: const [
      OrderItem(
        name: 'Com Tam Suon Bi Cha',
        quantity: 2,
        unitPriceVnd: 58000,
        note: 'No scallion oil',
      ),
    ],
    totalAmountVnd: 116000,
    status: OrderStatus.newOrder,
    createdAt: DateTime.utc(2026, 11, 18, 9, 5),
    updatedAt: DateTime.utc(2026, 11, 18, 9, 5),
    kitchenNotes: 'Peanut allergy',
  );

  setUpAll(() {
    registerFallbackValue(
      OrderTransitionRequested(
        order: newOrder,
        targetStatus: OrderStatus.preparing,
      ),
    );
  });

  setUp(() {
    actionBloc = _MockOrderActionBloc();
    when(() => actionBloc.state).thenReturn(const OrderActionIdle());
  });

  Widget buildDetail(
    Order order, {
    double width = 360,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 720),
        viewInsets: viewInsets,
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<OrderActionBloc>.value(
          value: actionBloc,
          child: OrderDetailView(order: order, clock: fixedClock),
        ),
      ),
    );
  }

  group('OrderDetailView & RejectOrderDialog', () {
    testWidgets(
      'disables Mark Ready and Handover to Rider when order is NEW',
      (tester) async {
        await tester.pumpWidget(buildDetail(newOrder));
        await tester.pumpAndSettle();

        final acceptButton = tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text('Accept & Prepare'),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        );
        final readyButton = tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text('Mark Ready'),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        );
        final handoverButton = tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text('Handover to Rider'),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        );
        final rejectButton = tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text('Reject Order'),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        );

        expect(acceptButton.onPressed, isNotNull);
        expect(rejectButton.onPressed, isNotNull);
        expect(readyButton.onPressed, isNull);
        expect(handoverButton.onPressed, isNull);
      },
    );

    testWidgets(
      'requires non-empty rejection reason in RejectOrderDialog and passes on narrow 320px keyboard insets',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildDetail(
            newOrder,
            width: 320,
            viewInsets: const EdgeInsets.only(bottom: 220),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reject Order'));
        await tester.pumpAndSettle();

        expect(find.text('Reject ORD-1028'), findsOneWidget);

        // Attempt empty submit -> validation error must block submission.
        await tester.tap(find.text('Confirm Reject'));
        await tester.pumpAndSettle();

        expect(find.text('Rejection reason is required'), findsOneWidget);
        verifyNever(() => actionBloc.add(any()));

        // Enter valid reason and confirm.
        await tester.enterText(
          find.byType(TextFormField),
          'Out of grilled pork',
        );
        await tester.tap(find.text('Confirm Reject'));
        await tester.pumpAndSettle();

        verify(
          () => actionBloc.add(
            OrderTransitionRequested(
              order: newOrder,
              targetStatus: OrderStatus.rejected,
              rejectionReason: 'Out of grilled pork',
            ),
          ),
        ).called(1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
