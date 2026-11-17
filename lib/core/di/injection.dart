import 'package:get_it/get_it.dart';
import 'package:orderpulse_flutter/core/config/app_config.dart';
import 'package:orderpulse_flutter/core/router/app_router.dart';
import 'package:orderpulse_flutter/core/theme/theme_cubit.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';

/// Global service locator for OrderPulse dependencies.
final GetIt sl = GetIt.instance;

/// Registers core and feature dependencies for the provided [config].
Future<void> configureDependencies({
  AppConfig? config,
  AppClock? clock,
}) async {
  await sl.reset(dispose: true);

  final resolvedConfig = config ?? AppConfig.fromEnvironment();
  final resolvedClock = clock ?? const SystemClock();

  sl.registerSingleton<AppConfig>(resolvedConfig);
  sl.registerSingleton<AppClock>(resolvedClock);
  sl.registerSingleton<ThemeCubit>(
    ThemeCubit(),
    dispose: (cubit) => cubit.close(),
  );
  sl.registerSingleton<AuthSessionGate>(
    AuthSessionGate(),
    dispose: (gate) => gate.dispose(),
  );
}
