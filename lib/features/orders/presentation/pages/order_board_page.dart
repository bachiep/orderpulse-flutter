import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';
import 'package:orderpulse_flutter/core/router/app_router.dart';
import 'package:orderpulse_flutter/core/theme/theme_cubit.dart';
import 'package:orderpulse_flutter/core/widgets/state_views.dart';

/// Merchant order board shell page.
class OrderBoardPage extends StatelessWidget {
  const OrderBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authGate = sl<AuthSessionGate>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('OrderPulse Dispatch'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () => context.read<ThemeCubit>().toggle(),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => authGate.setAuthenticated(false),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: EmptyStateView(
          title: 'Dispatch Board Ready',
          subtitle: 'Order streams and live queue controls will load here.',
          actionLabel: 'Refresh',
          onAction: () {},
        ),
      ),
    );
  }
}
