import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/core/config/app_config.dart';
import 'package:orderpulse_flutter/core/network/dio_client.dart';
import 'package:orderpulse_flutter/core/network/token_storage.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/features/auth/data/auth_repository_impl.dart';
import 'package:orderpulse_flutter/features/realtime/data/demo_order_realtime_source.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_event.dart';
import 'package:orderpulse_flutter/features/realtime/presentation/bloc/order_stream_bloc.dart';
import 'package:orderpulse_flutter/features/simulator/data/demo_backend_engine.dart';
import 'package:orderpulse_flutter/features/simulator/data/demo_network_simulator.dart';
import 'package:orderpulse_flutter/features/simulator/data/live_network_simulator.dart';
import 'package:orderpulse_flutter/features/simulator/presentation/bloc/simulator_cubit.dart';
import 'package:orderpulse_flutter/features/simulator/presentation/widgets/simulator_sheet.dart';

void main() {
  const demoConfig = AppConfig(
    environment: AppEnvironment.demo,
    apiBaseUrl: 'http://10.0.2.2:8301',
    wsBaseUrl: 'ws://10.0.2.2:8301/ws/orders',
  );

  group('SimulatorCubit & DemoNetworkSimulator', () {
    test(
      'executes real 3-way concurrent 401 refresh with single /auth/refresh, pushes order, and detects expired refresh logout',
      () async {
        final clock = FixedClock(DateTime.utc(2026, 11, 18, 10, 0));
        final engine = DemoBackendEngine(
          clock: clock,
          simulatedLatency: Duration.zero,
        );
        final tokenStorage = InMemoryTokenStorage();
        final traceBuffer = AuthTraceBuffer();
        var expiredSignalCount = 0;

        final dioClient = DioClient(
          config: demoConfig,
          tokenStorage: tokenStorage,
          adapter: DemoBackendHttpAdapter(engine),
          onSessionExpired: () => expiredSignalCount += 1,
          onTrace: traceBuffer.add,
        );
        final authRepo = AuthRepositoryImpl(
          dio: dioClient.dio,
          tokenStorage: tokenStorage,
        );
        await authRepo.signIn(
          email: 'merchant@orderpulse.demo',
          password: 'demo',
        );

        final realtimeSource = DemoOrderRealtimeDataSource();
        final stream = await realtimeSource.connect();
        final receivedEvents = <OrderRealtimeEvent>[];
        final sub = stream.listen(receivedEvents.add);

        final simulator = DemoNetworkSimulator(
          engine: engine,
          realtimeSource: realtimeSource,
          dio: dioClient.dio,
          traceBuffer: traceBuffer,
        );
        final cubit = SimulatorCubit(service: simulator);

        await cubit.pushIncomingOrder();
        await Future<void>.delayed(Duration.zero);
        expect(receivedEvents, hasLength(1));
        expect(receivedEvents.first, isA<OrderCreatedEvent>());

        await cubit.testConcurrent401Refresh();
        expect(cubit.state.lastRefreshReport, isNotNull);
        expect(cubit.state.lastRefreshReport!.requestCount, 3);
        expect(cubit.state.lastRefreshReport!.succeededCount, 3);
        expect(cubit.state.lastRefreshReport!.refreshCallsExecuted, 1);
        expect(expiredSignalCount, 0);

        await cubit.simulateExpiredRefreshLogout();
        expect(expiredSignalCount, 1);
        expect(await tokenStorage.readTokens(), isNull);

        await sub.cancel();
        await realtimeSource.disconnect();
        await cubit.close();
      },
    );

    test('UnavailableNetworkSimulator keeps isSupported=false in live mode', () async {
      final cubit = SimulatorCubit(service: const UnavailableNetworkSimulator());
      expect(cubit.state.isSupported, isFalse);

      await cubit.pushIncomingOrder();
      expect(cubit.state.eventLog, isEmpty);
      await cubit.close();
    });
  });

  group('SimulatorSheet narrow viewport safety', () {
    testWidgets(
      'renders all controls and 401 report without overflow on 320px width + keyboard insets',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final engine = DemoBackendEngine(simulatedLatency: Duration.zero);
        final tokenStorage = InMemoryTokenStorage(
          initialTokens: AuthTokens(
            accessToken: engine.activeAccessToken,
            refreshToken: engine.activeRefreshToken,
          ),
        );
        final traceBuffer = AuthTraceBuffer();
        final dioClient = DioClient(
          config: demoConfig,
          tokenStorage: tokenStorage,
          adapter: DemoBackendHttpAdapter(engine),
          onSessionExpired: () {},
          onTrace: traceBuffer.add,
        );

        final realtimeSource = DemoOrderRealtimeDataSource();
        final streamBloc = OrderStreamBloc(dataSource: realtimeSource);
        final cubit = SimulatorCubit(
          service: DemoNetworkSimulator(
            engine: engine,
            realtimeSource: realtimeSource,
            dio: dioClient.dio,
            traceBuffer: traceBuffer,
          ),
        );
        addTearDown(() {
          unawaited(cubit.close());
          unawaited(streamBloc.close());
        });

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: MultiBlocProvider(
                  providers: [
                    BlocProvider<SimulatorCubit>.value(value: cubit),
                    BlocProvider<OrderStreamBloc>.value(value: streamBloc),
                  ],
                  child: const SimulatorSheet(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Network & Stream Simulator'), findsOneWidget);
        expect(find.text('Push Incoming Live Order'), findsOneWidget);

        await tester.tap(
          find.text('Expire Token & Fire 3 Parallel Requests'),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Last 401 Queue Verification'), findsOneWidget);
        expect(
          find.text('Refresh calls executed: 1 (single-flight verified)'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );
  });
}
