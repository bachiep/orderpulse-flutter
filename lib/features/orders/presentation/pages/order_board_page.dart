import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/theme/theme_cubit.dart';
import 'package:orderpulse_flutter/core/widgets/state_views.dart';
import 'package:orderpulse_flutter/features/auth/presentation/bloc/auth_bloc.dart';

/// Merchant order board shell page.
class OrderBoardPage extends StatelessWidget {
  const OrderBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final title = switch (authState) {
      AuthAuthenticated(:final merchant) => merchant.merchantName,
      _ => 'OrderPulse Dispatch',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () => context.read<ThemeCubit>().toggle(),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => context.read<AuthBloc>().add(
                  const AuthLogoutRequested(),
                ),
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
