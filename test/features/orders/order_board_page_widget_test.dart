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

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _MockOrderBoardBloc extends MockBloc<OrderBoardEvent, OrderBoardState>
    implements OrderBoardBloc {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockOrderBoardBloc boardBloc;
  late OrderFilterCubit filterCubit;
  late OrderSearchBloc searchBloc;
  late ThemeCubit themeCubit;
  final fixedClock = FixedClock(DateTime.utc(2026, 11, 18, 9, 0));

  const merchant = MerchantProfile(
    id: 'm1',
    merchantName: 'OrderPulse Kitchen - Demo',
    branchName: 'District 1',
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
    filterCubit = OrderFilterCubit();
    searchBloc = OrderSearchBloc(debounceDuration: Duration.zero);
    themeCubit = ThemeCubit();

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(merchant));
  });

  tearDown(() async {
    await filterCubit.close();
    await searchBloc.close();
    await themeCubit.close();
  });

  Widget wrapBoard({double width = 400}) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 760)),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ThemeCubit>.value(value: themeCubit),
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<OrderBoardBloc>.value(value: boardBloc),
            BlocProvider<OrderFilterCubit>.value(value: filterCubit),
            BlocProvider<OrderSearchBloc>.value(value: searchBloc),
          ],
          child: OrderBoardView(clock: fixedClock),
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
  });
}
