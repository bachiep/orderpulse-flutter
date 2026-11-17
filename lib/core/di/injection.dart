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
import 'package:orderpulse_flutter/features/simulator/data/demo_backend_engine.dart';

/// Global service locator for OrderPulse dependencies.
final GetIt sl = GetIt.instance;

const String _envScopeName = 'environment-scope';

/// Manages dynamic swapping of Live vs. Demo dependencies via `get_it` scopes.
class GetItEnvironmentConfigurator implements EnvironmentConfigurator {
  GetItEnvironmentConfigurator(this._currentConfig, {this.demoLatency});

  AppConfig _currentConfig;
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
        } else {
          final tokenStorage = SecureTokenStorage();
          final dioClient = DioClient(
            config: config,
            tokenStorage: tokenStorage,
            onSessionExpired: _notifySessionExpired,
          );

          getIt.registerSingleton<TokenStorage>(tokenStorage);
          getIt.registerSingleton<DioClient>(dioClient);
        }

        getIt.registerSingleton<Dio>(getIt<DioClient>().dio);
        getIt.registerSingleton<AuthRepository>(
          AuthRepositoryImpl(
            dio: getIt<Dio>(),
            tokenStorage: getIt<TokenStorage>(),
          ),
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

/// Registers base and active environment dependencies for the application.
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
    demoLatency: demoLatency,
  );

  sl.registerSingleton<AppClock>(resolvedClock);
  sl.registerSingleton<ThemeCubit>(
    ThemeCubit(),
    dispose: (cubit) => cubit.close(),
  );
  sl.registerSingleton<AuthSessionGate>(
    AuthSessionGate(),
    dispose: (gate) => gate.dispose(),
  );
  sl.registerSingleton<EnvironmentConfigurator>(envConfigurator);

  await envConfigurator.activateEnvironment(resolvedConfig);

  sl.registerSingleton<AuthBloc>(
    AuthBloc(
      environmentConfigurator: envConfigurator,
      authRepositoryProvider: () => sl<AuthRepository>(),
      authGate: sl<AuthSessionGate>(),
    ),
    dispose: (bloc) => bloc.close(),
  );
}
