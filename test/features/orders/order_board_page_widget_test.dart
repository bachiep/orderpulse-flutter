import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/theme/theme_cubit.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/core/widgets/state_views.dart';
import 'package:orderpulse_flutter/features/auth/domain/merchant_profile.dart';
import 'package:orderpulse_flutter/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_board_bloc.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_filter_cubit.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_search_bloc.dart';
import 'package:orderpulse_flutter/features/orders/presentation/pages/order_board_page.dart';
import 'package:orderpulse_flutter/features/realtime/presentation/bloc/order_stream_bloc.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _MockOrderBoardBloc extends MockBloc<OrderBoardEvent, OrderBoardState>
    implements OrderBoardBloc {}

class _MockOrderStreamBloc
    extends MockBloc<OrderStreamEvent, OrderStreamState>
    implements OrderStreamBloc {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockOrderBoardBloc boardBloc;
  late _MockOrderStreamBloc streamBloc;
  late OrderFilterCubit filterCubit;
  late OrderSearchBloc searchBloc;
  late ThemeCubit themeCubit;
  final fixedClock = FixedClock(DateTime.utc(2026, 11, 18, 9, 0));

  const merchant = MerchantProfile(
    id: 'merchant-demo-01',
    merchantName: 'OrderPulse',
    branchName: 'District 1 • Demo Kitchen',
    email: 'merchant@orderpulse.demo',
  );

  final sampleOrder = Order(
    id: 'ORD-1028',
    customerName: 'Tran Minh Anh',
    customerPhone: '0912 *** 401',
    items: const [
      OrderItem(name: 'Com Tam Suon Bi Cha', quantity: 2, unitPriceVnd: 58000),
    ],
    totalAmountVnd: 116000,
    status: OrderStatus.newOrder,
    createdAt: DateTime.utc(2026, 11, 18, 8, 55),
    updatedAt: DateTime.utc(2026, 11, 18, 8, 55),
    kitchenNotes: 'No peanuts please',
  );

  setUpAll(() {
    registerFallbackValue(const OrderBoardLoadRequested());
    registerFallbackValue(const OrderBoardFilterChanged(OrderFilterTab.all));
    registerFallbackValue(const OrderBoardQueryChanged(''));
  });

  setUp(() {
    authBloc = _MockAuthBloc();
    boardBloc = _MockOrderBoardBloc();
    streamBloc = _MockOrderStreamBloc();
    filterCubit = OrderFilterCubit();
    searchBloc = OrderSearchBloc(debounceDuration: Duration.zero);
    themeCubit = ThemeCubit();

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(merchant));
    when(() => streamBloc.state).thenReturn(const OrderStreamLive());
  });

  tearDown(() async {
    await filterCubit.close();
    await searchBloc.close();
    await themeCubit.close();
  });

  Widget wrapBoard({
    double width = 400,
    List<Order>? shiftOrders,
  }) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 852)),
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ThemeCubit>.value(value: themeCubit),
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<OrderBoardBloc>.value(value: boardBloc),
            BlocProvider<OrderStreamBloc>.value(value: streamBloc),
            BlocProvider<OrderFilterCubit>.value(value: filterCubit),
            BlocProvider<OrderSearchBloc>.value(value: searchBloc),
          ],
          child: OrderBoardView(
            clock: fixedClock,
            shiftOrders: shiftOrders,
          ),
        ),
      ),
    );
  }

  group('OrderBoardView 4 UI states & narrow screen safety', () {
    testWidgets('renders Loading state', (tester) async {
      when(() => boardBloc.state).thenReturn(const OrderBoardLoading());

      await tester.pumpWidget(wrapBoard());
      expect(find.byType(LoadingStateView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders Loaded state cleanly on 320px width without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => boardBloc.state).thenReturn(
        OrderBoardLoaded(
          orders: [sampleOrder],
          stats: const MerchantShiftStats(
            activeCount: 4,
            completedToday: 8,
            revenueTodayVnd: 1200000,
            avgPrepMinutes: 11.4,
          ),
          filter: OrderFilterTab.all,
          searchQuery: '',
          page: 1,
          hasMore: true,
          totalCount: 2,
        ),
      );

      await tester.pumpWidget(wrapBoard(width: 320));
      await tester.pumpAndSettle();

      expect(find.text('ORD-1028'), findsOneWidget);
      expect(find.text('Tran Minh Anh'), findsOneWidget);
      expect(find.text('Load More Orders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Empty state with Reset Filters CTA', (tester) async {
      filterCubit.selectTab(OrderFilterTab.rejected);
      when(() => boardBloc.state).thenReturn(
        const OrderBoardEmpty(
          filter: OrderFilterTab.rejected,
          searchQuery: '',
        ),
      );

      await tester.pumpWidget(wrapBoard());
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      await tester.tap(find.text('Reset Filters'));
      await tester.pump();
      expect(filterCubit.state, OrderFilterTab.all);
    });

    testWidgets('renders Error state with working Retry button', (tester) async {
      when(() => boardBloc.state).thenReturn(
        const OrderBoardError(
          message: 'Server unreachable (503)',
          filter: OrderFilterTab.all,
          searchQuery: '',
        ),
      );

      await tester.pumpWidget(wrapBoard());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.text('Server unreachable (503)'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      verify(() => boardBloc.add(const OrderBoardLoadRequested())).called(1);
    });

    testWidgets(
      'renders unclipped 2-line AppBar at 393px with LIVE pill and SLA badges',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final urgentOrder = Order(
          id: 'ORD-1025',
          customerName: 'Vo Tuan Kiet',
          customerPhone: '0908 *** 623',
          items: const [
            OrderItem(name: 'Bun Bo Hue', quantity: 3, unitPriceVnd: 68000),
          ],
          totalAmountVnd: 204000,
          status: OrderStatus.preparing,
          createdAt: DateTime.utc(2026, 11, 18, 8, 41), // 19m ago -> +4m OVERDUE
          updatedAt: DateTime.utc(2026, 11, 18, 8, 45),
        );

        when(() => boardBloc.state).thenReturn(
          OrderBoardLoaded(
            orders: [sampleOrder, urgentOrder],
            stats: const MerchantShiftStats(
              activeCount: 2,
              completedToday: 5,
              revenueTodayVnd: 800000,
              avgPrepMinutes: 11.4,
            ),
            filter: OrderFilterTab.all,
            searchQuery: '',
            page: 1,
            hasMore: false,
            totalCount: 2,
          ),
        );

        await tester.pumpWidget(wrapBoard(width: 393));
        await tester.pumpAndSettle();

        expect(find.text('OrderPulse'), findsOneWidget);
        expect(find.text('District 1 • Demo Kitchen'), findsOneWidget);
        expect(find.text('LIVE'), findsOneWidget);
        expect(find.text('10m left'), findsOneWidget);
        expect(find.text('+4m OVERDUE'), findsOneWidget);

        // Verify the AppBar reserves generous unclipped width for the 2-line subtitle at 393px.
        final renderBox = tester.renderObject<RenderBox>(
          find.text('District 1 • Demo Kitchen'),
        );
        expect(renderBox.size.width, greaterThanOrEqualTo(180));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'switches to Shift Insights tab and renders KPIs, charts, and Top 5 Dishes cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final completedOrder = Order(
          id: 'ORD-1022',
          customerName: 'Bui Khanh Linh',
          customerPhone: '0919 *** 224',
          items: const [
            OrderItem(
              name: 'Pho Bo Tai Nam',
              quantity: 3,
              unitPriceVnd: 72000,
              isPrepped: true,
            ),
          ],
          totalAmountVnd: 216000,
          status: OrderStatus.completed,
          createdAt: DateTime.utc(2026, 11, 18, 7, 30),
          updatedAt: DateTime.utc(2026, 11, 18, 7, 41),
          readyAt: DateTime.utc(2026, 11, 18, 7, 40),
          completedAt: DateTime.utc(2026, 11, 18, 7, 41),
        );

        when(() => boardBloc.state).thenReturn(
          OrderBoardLoaded(
            orders: [sampleOrder, completedOrder],
            stats: const MerchantShiftStats(
              activeCount: 1,
              completedToday: 1,
              revenueTodayVnd: 216000,
              avgPrepMinutes: 10.0,
            ),
            filter: OrderFilterTab.all,
            searchQuery: '',
            page: 1,
            hasMore: false,
            totalCount: 2,
          ),
        );

        await tester.pumpWidget(
          wrapBoard(width: 393, shiftOrders: [sampleOrder, completedOrder]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Shift Insights'));
        await tester.pumpAndSettle();

        expect(find.text('Completed Orders'), findsOneWidget);
        expect(find.text('Gross Revenue'), findsOneWidget);
        expect(find.text('Avg Prep Time'), findsOneWidget);
        expect(find.text('On-Time SLA %'), findsOneWidget);
        expect(find.text('Hourly Order Volume'), findsOneWidget);
        expect(find.text('Status Distribution'), findsOneWidget);
        expect(find.text('Top 5 Dishes'), findsOneWidget);
        expect(find.text('Pho Bo Tai Nam'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders Shift Insights tab cleanly on narrow 320px width without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        when(() => boardBloc.state).thenReturn(
          OrderBoardLoaded(
            orders: [sampleOrder],
            stats: const MerchantShiftStats(
              activeCount: 1,
              completedToday: 0,
              revenueTodayVnd: 0,
              avgPrepMinutes: 0,
            ),
            filter: OrderFilterTab.all,
            searchQuery: '',
            page: 1,
            hasMore: false,
            totalCount: 1,
          ),
        );

        await tester.pumpWidget(wrapBoard(width: 320, shiftOrders: [sampleOrder]));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Shift Insights'));
        await tester.pumpAndSettle();

        expect(find.text('Completed Orders'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Top 5 Dishes'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Top 5 Dishes'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
