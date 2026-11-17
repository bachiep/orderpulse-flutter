import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';
import 'package:orderpulse_flutter/core/router/app_router.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/theme/theme_cubit.dart';
import 'package:orderpulse_flutter/features/auth/presentation/pages/login_page.dart';
import 'package:orderpulse_flutter/features/orders/presentation/pages/order_board_page.dart';

/// Root OrderPulse application widget wiring Material 3 themes, BLoCs, and routing.
class OrderPulseApp extends StatefulWidget {
  const OrderPulseApp({super.key});

  @override
  State<OrderPulseApp> createState() => _OrderPulseAppState();
}

class _OrderPulseAppState extends State<OrderPulseApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(
      authGate: sl<AuthSessionGate>(),
      loginBuilder: (_) => const LoginPage(),
      ordersBuilder: (_) => const OrderBoardPage(),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<ThemeCubit>(),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: 'OrderPulse Merchant',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
