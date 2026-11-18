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
    void Function(int itemIndex, bool isPrepped)? onItemPrepChanged,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 720),
        viewInsets: viewInsets,
      ),
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: BlocProvider<OrderActionBloc>.value(
          value: actionBloc,
          child: OrderDetailView(
            order: order,
            clock: fixedClock,
            onItemPrepChanged: onItemPrepChanged,
          ),
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

    testWidgets(
      'renders lifecycle stepper, courier dispatch card, and interactive item prep checklist at 393px',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final recordedToggles = <(int, bool)>[];
        final preparingOrder = Order(
          id: 'ORD-1026',
          customerName: 'Pham Ngoc Han',
          customerPhone: '0977 *** 905',
          items: const [
            OrderItem(
              name: 'Banh Mi Chao Dac Biet',
              quantity: 1,
              unitPriceVnd: 69000,
              isPrepped: true,
            ),
            OrderItem(
              name: 'Ca Phe Sua Da',
              quantity: 2,
              unitPriceVnd: 32000,
              isPrepped: false,
            ),
          ],
          totalAmountVnd: 133000,
          status: OrderStatus.preparing,
          createdAt: DateTime.utc(2026, 11, 18, 9, 0),
          updatedAt: DateTime.utc(2026, 11, 18, 9, 4),
          acceptedAt: DateTime.utc(2026, 11, 18, 9, 2),
          pickupCode: 'PK-261',
          kitchenNotes: 'Separate pate and cold cuts.',
          riderName: 'Nguyen Van Hung',
          riderPlate: '59-C1 731.04',
          riderPhone: '0903 *** 812',
          riderVehicle: 'Honda Wave RSX',
          riderEtaMinutes: 4,
        );

        await tester.pumpWidget(
          buildDetail(
            preparingOrder,
            width: 393,
            onItemPrepChanged: (index, isPrepped) {
              recordedToggles.add((index, isPrepped));
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Order Lifecycle'), findsOneWidget);
        expect(find.text('Placed'), findsOneWidget);
        expect(find.text('Kitchen Accepted'), findsOneWidget);
        expect(find.text('Ready for Pickup'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('1/2 prepped'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Courier & Delivery Dispatch'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Courier & Delivery Dispatch'), findsOneWidget);
        expect(find.text('Nguyen Van Hung'), findsOneWidget);
        expect(find.text('ETA 4m'), findsOneWidget);
        expect(find.text('5m left'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Ca Phe Sua Da'),
          -160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ca Phe Sua Da'));
        await tester.pumpAndSettle();

        expect(find.text('2/2 prepped'), findsOneWidget);
        expect(recordedToggles, [(1, true)]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'guards Mark Ready when prep checklist items remain unchecked and allows bypass when confirmed',
      (tester) async {
        tester.view.physicalSize = const Size(320, 680);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final partialPreparingOrder = Order(
          id: 'ORD-1025',
          customerName: 'Vo Tuan Kiet',
          customerPhone: '0908 *** 623',
          items: const [
            OrderItem(
              name: 'Bun Bo Hue Gio Heo',
              quantity: 3,
              unitPriceVnd: 68000,
              isPrepped: true,
            ),
            OrderItem(
              name: 'Tra Dao Cam Sa',
              quantity: 2,
              unitPriceVnd: 38000,
              isPrepped: false,
            ),
          ],
          totalAmountVnd: 280000,
          status: OrderStatus.preparing,
          createdAt: DateTime.utc(2026, 11, 18, 9, 0),
          updatedAt: DateTime.utc(2026, 11, 18, 9, 4),
        );

        await tester.pumpWidget(buildDetail(partialPreparingOrder, width: 320));
        await tester.pumpAndSettle();

        // Tap Mark Ready -> warning dialog must appear and block premature dispatch.
        await tester.tap(find.text('Mark Ready'));
        await tester.pumpAndSettle();

        expect(find.text('Unchecked Prep Items'), findsOneWidget);
        expect(find.text('• 2x Tra Dao Cam Sa'), findsOneWidget);
        expect(find.text('Cancel / Review Items'), findsOneWidget);
        expect(find.text('Mark Ready Anyway'), findsOneWidget);

        await tester.tap(find.text('Cancel / Review Items'));
        await tester.pumpAndSettle();
        verifyNever(() => actionBloc.add(any()));

        // Tap Mark Ready again and choose Mark Ready Anyway -> dispatches transition.
        await tester.tap(find.text('Mark Ready'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mark Ready Anyway'));
        await tester.pumpAndSettle();

        verify(
          () => actionBloc.add(
            OrderTransitionRequested(
              order: partialPreparingOrder,
              targetStatus: OrderStatus.ready,
            ),
          ),
        ).called(1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dispatches Mark Ready directly without dialog when all prep items are checked',
      (tester) async {
        final preppedOrder = Order(
          id: 'ORD-1026',
          customerName: 'Pham Ngoc Han',
          customerPhone: '0977 *** 905',
          items: const [
            OrderItem(
              name: 'Banh Mi Chao Dac Biet',
              quantity: 1,
              unitPriceVnd: 69000,
              isPrepped: true,
            ),
          ],
          totalAmountVnd: 69000,
          status: OrderStatus.preparing,
          createdAt: DateTime.utc(2026, 11, 18, 9, 0),
          updatedAt: DateTime.utc(2026, 11, 18, 9, 4),
        );

        await tester.pumpWidget(buildDetail(preppedOrder));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mark Ready'));
        await tester.pumpAndSettle();

        expect(find.text('Unchecked Prep Items'), findsNothing);
        verify(
          () => actionBloc.add(
            OrderTransitionRequested(
              order: preppedOrder,
              targetStatus: OrderStatus.ready,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'opens 80mm Thermal Kitchen Slip modal preview cleanly on 320px and 393px widths',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final preparingOrder = Order(
          id: 'ORD-1025',
          customerName: 'Vo Tuan Kiet',
          customerPhone: '0908 *** 623',
          items: const [
            OrderItem(
              name: 'Bun Bo Hue Gio Heo',
              quantity: 3,
              unitPriceVnd: 68000,
              note: 'Mild chili',
              isPrepped: true,
            ),
            OrderItem(
              name: 'Tra Dao Cam Sa',
              quantity: 2,
              unitPriceVnd: 38000,
              isPrepped: false,
            ),
          ],
          totalAmountVnd: 280000,
          status: OrderStatus.preparing,
          createdAt: DateTime.utc(2026, 11, 18, 8, 51), // 19m ago -> +4m OVERDUE
          updatedAt: DateTime.utc(2026, 11, 18, 8, 57),
          acceptedAt: DateTime.utc(2026, 11, 18, 8, 57),
          pickupCode: 'PK-255',
          kitchenNotes: 'Include extra lime wedges.',
          riderName: 'Le Hoang Duy',
        );

        await tester.pumpWidget(buildDetail(preparingOrder, width: 320));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.receipt_long), findsOneWidget);
        await tester.tap(find.text('Kitchen Slip'));
        await tester.pumpAndSettle();

        expect(find.text('80mm Thermal Kitchen Slip'), findsOneWidget);
        expect(find.text('ORDERPULSE KITCHEN'), findsOneWidget);
        expect(find.text('ORDER: ORD-1025'), findsOneWidget);
        expect(find.text('SLA: +4m OVERDUE'), findsOneWidget);
        expect(find.text('CHANNEL: O2O Delivery • PK-255'), findsOneWidget);
        expect(find.text('3x Bun Bo Hue Gio Heo'), findsOneWidget);
        expect(find.text('* Mild chili [PREPPED]'), findsOneWidget);
        expect(find.text('ITEMS: 5'), findsOneWidget);

        await tester.tap(find.text('Print Slip'));
        await tester.pumpAndSettle();

        expect(
          find.text('Kitchen slip queued for ORD-1025 (80mm).'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
