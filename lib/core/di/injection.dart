import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:orderpulse_flutter/core/config/app_config.dart';
import 'package:orderpulse_flutter/core/network/dio_client.dart';
import 'package:orderpulse_flutter/core/network/token_storage.dart';
import 'package:orderpulse_flutter/core/router/app_router.dart';
import 'package:orderpulse_flutter/core/theme/theme_cubit.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/features/auth/data/auth_repository_impl.dart';
import 'package:orderpulse_flutter/features/auth/domain/auth_repository.dart';
import 'package:orderpulse_flutter/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/bloc/order_action_bloc.dart';
import 'package:orderpulse_flutter/features/orders/data/order_repository_impl.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_board_bloc.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_filter_cubit.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_search_bloc.dart';
import 'package:orderpulse_flutter/features/realtime/data/demo_order_realtime_source.dart';
import 'package:orderpulse_flutter/features/realtime/data/ws_order_realtime_source.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_source.dart';
import 'package:orderpulse_flutter/features/realtime/presentation/bloc/order_stream_bloc.dart';
import 'package:orderpulse_flutter/features/simulator/data/demo_backend_engine.dart';

/// Global service locator for OrderPulse dependencies.
final GetIt sl = GetIt.instance;

const String _envScopeName = 'environment-scope';

/// Manages dynamic swapping of Live vs. Demo dependencies via `get_it` scopes.
class GetItEnvironmentConfigurator implements EnvironmentConfigurator {
  GetItEnvironmentConfigurator(
    this._currentConfig, {
    required AppClock clock,
    this.demoLatency,
  })  : _clock = clock;

  AppConfig _currentConfig;
  final AppClock _clock;
  final Duration? demoLatency;

  @override
  AppConfig get currentConfig => _currentConfig;

  @override
  Future<void> activateEnvironment(AppConfig config) async {
    _currentConfig = config;
    if (sl.hasScope(_envScopeName)) {
      await sl.dropScope(_envScopeName);
    }

    sl.pushNewScope(
      scopeName: _envScopeName,
      init: (getIt) {
        getIt.registerSingleton<AppConfig>(config);

        if (config.environment == AppEnvironment.demo) {
          final engine = DemoBackendEngine(
            clock: _clock,
            simulatedLatency: demoLatency ?? const Duration(milliseconds: 90),
          );
          final tokenStorage = InMemoryTokenStorage();
          final dioClient = DioClient(
            config: config,
            tokenStorage: tokenStorage,
            adapter: DemoBackendHttpAdapter(engine),
            onSessionExpired: _notifySessionExpired,
          );

          getIt.registerSingleton<DemoBackendEngine>(engine);
          getIt.registerSingleton<TokenStorage>(tokenStorage);
          getIt.registerSingleton<DioClient>(dioClient);
          getIt.registerSingleton<OrderRealtimeDataSource>(
            DemoOrderRealtimeDataSource(),
          );
        } else {
          final tokenStorage = SecureTokenStorage();
          final dioClient = DioClient(
            config: config,
            tokenStorage: tokenStorage,
            onSessionExpired: _notifySessionExpired,
          );

          getIt.registerSingleton<TokenStorage>(tokenStorage);
          getIt.registerSingleton<DioClient>(dioClient);
          getIt.registerSingleton<OrderRealtimeDataSource>(
            WsOrderRealtimeDataSource(
              config: config,
              tokenStorage: tokenStorage,
            ),
          );
        }

        getIt.registerSingleton<Dio>(getIt<DioClient>().dio);
        getIt.registerSingleton<AuthRepository>(
          AuthRepositoryImpl(
            dio: getIt<Dio>(),
            tokenStorage: getIt<TokenStorage>(),
          ),
        );
        getIt.registerSingleton<OrderRepository>(
          OrderRepositoryImpl(dio: getIt<Dio>()),
        );

        getIt.registerSingleton<OrderFilterCubit>(
          OrderFilterCubit(),
          dispose: (cubit) => unawaited(cubit.close()),
        );
        getIt.registerSingleton<OrderSearchBloc>(
          OrderSearchBloc(),
          dispose: (bloc) => unawaited(bloc.close()),
        );
        getIt.registerSingleton<OrderBoardBloc>(
          OrderBoardBloc(orderRepository: getIt<OrderRepository>()),
          dispose: (bloc) => unawaited(bloc.close()),
        );
        getIt.registerSingleton<OrderActionBloc>(
          OrderActionBloc(orderRepository: getIt<OrderRepository>()),
          dispose: (bloc) => unawaited(bloc.close()),
        );
        getIt.registerSingleton<OrderStreamBloc>(
          OrderStreamBloc(
            dataSource: getIt<OrderRealtimeDataSource>(),
            clock: _clock,
          ),
          dispose: (bloc) => unawaited(bloc.close()),
        );
      },
    );
  }

  void _notifySessionExpired() {
    if (sl.isRegistered<AuthBloc>()) {
      sl<AuthBloc>().add(const AuthSessionExpiredReceived());
    }
  }
}

/// Registers base-scope and active environment-scope dependencies.
Future<void> configureDependencies({
  AppConfig? config,
  AppClock? clock,
  Duration? demoLatency,
}) async {
  await sl.reset(dispose: true);

  final resolvedConfig = config ?? AppConfig.fromEnvironment();
  final resolvedClock = clock ?? const SystemClock();

  final envConfigurator = GetItEnvironmentConfigurator(
    resolvedConfig,
    clock: resolvedClock,
    demoLatency: demoLatency,
  );

  sl.registerSingleton<AppClock>(resolvedClock);
  sl.registerSingleton<ThemeCubit>(
    ThemeCubit(),
    dispose: (cubit) => unawaited(cubit.close()),
  );
  sl.registerSingleton<AuthSessionGate>(
    AuthSessionGate(),
    dispose: (gate) => gate.dispose(),
  );
  sl.registerSingleton<EnvironmentConfigurator>(envConfigurator);
  sl.registerSingleton<AuthBloc>(
    AuthBloc(
      environmentConfigurator: envConfigurator,
      authRepositoryProvider: () => sl<AuthRepository>(),
      authGate: sl<AuthSessionGate>(),
    ),
    dispose: (bloc) => unawaited(bloc.close()),
  );

  await envConfigurator.activateEnvironment(resolvedConfig);
}
