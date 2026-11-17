import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';
import 'package:orderpulse_flutter/core/theme/theme_cubit.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/core/widgets/state_views.dart';
import 'package:orderpulse_flutter/core/widgets/status_badge.dart';
import 'package:orderpulse_flutter/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_board_bloc.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_filter_cubit.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_search_bloc.dart';
import 'package:orderpulse_flutter/features/orders/presentation/widgets/order_card.dart';

/// Dependency-injected entry point for the merchant order dispatch board.
class OrderBoardPage extends StatefulWidget {
  const OrderBoardPage({super.key});

  @override
  State<OrderBoardPage> createState() => _OrderBoardPageState();
}

class _OrderBoardPageState extends State<OrderBoardPage> {
  @override
  void initState() {
    super.initState();
    final boardBloc = sl<OrderBoardBloc>();
    if (boardBloc.state is OrderBoardLoading) {
      boardBloc.add(const OrderBoardLoadRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<OrderBoardBloc>()),
        BlocProvider.value(value: sl<OrderFilterCubit>()),
        BlocProvider.value(value: sl<OrderSearchBloc>()),
      ],
      child: OrderBoardView(clock: sl<AppClock>()),
    );
  }
}

/// Declarative order board rendering Loading, Loaded, Empty, and Error UI states.
class OrderBoardView extends StatefulWidget {
  const OrderBoardView({
    super.key,
    required this.clock,
    this.onOrderTap,
  });

  final AppClock clock;
  final void Function(Order order)? onOrderTap;

  @override
  State<OrderBoardView> createState() => _OrderBoardViewState();
}

class _OrderBoardViewState extends State<OrderBoardView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160) {
      context.read<OrderBoardBloc>().add(const OrderBoardLoadMoreRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final title = switch (authState) {
      AuthAuthenticated(:final merchant) => merchant.merchantName,
      _ => 'OrderPulse Dispatch',
    };

    return MultiBlocListener(
      listeners: [
        BlocListener<OrderFilterCubit, OrderFilterTab>(
          listener: (context, tab) {
            context.read<OrderBoardBloc>().add(OrderBoardFilterChanged(tab));
          },
        ),
        BlocListener<OrderSearchBloc, OrderSearchState>(
          listener: (context, searchState) {
            context
                .read<OrderBoardBloc>()
                .add(OrderBoardQueryChanged(searchState.query));
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: 'Toggle theme',
              onPressed: () => context.read<ThemeCubit>().toggle(),
              icon: const Icon(Icons.brightness_6_outlined),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: () =>
                  context.read<AuthBloc>().add(const AuthLogoutRequested()),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _ShiftSummaryStrip(
                stats: context.select<OrderBoardBloc, MerchantShiftStats?>(
                  (bloc) => bloc.state.stats,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => context
                      .read<OrderSearchBloc>()
                      .add(OrderSearchQueryChanged(value)),
                  decoration: InputDecoration(
                    hintText: 'Search order ID or customer...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            context
                                .read<OrderSearchBloc>()
                                .add(const OrderSearchCleared());
                          },
                          icon: const Icon(Icons.close_rounded),
                        );
                      },
                    ),
                  ),
                ),
              ),
              _StatusFilterTabs(
                selected: context.watch<OrderFilterCubit>().state,
                onSelected: (tab) =>
                    context.read<OrderFilterCubit>().selectTab(tab),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: BlocBuilder<OrderBoardBloc, OrderBoardState>(
                  builder: (context, state) {
                    return switch (state) {
                      OrderBoardLoading() => const LoadingStateView(
                          message: 'Loading live merchant orders...',
                        ),
                      OrderBoardError(:final message) => ErrorStateView(
                          message: message,
                          onRetry: () => context
                              .read<OrderBoardBloc>()
                              .add(const OrderBoardLoadRequested()),
                        ),
                      OrderBoardEmpty(:final filter, :final searchQuery) =>
                        EmptyStateView(
                          title: 'No matching orders',
                          subtitle: searchQuery.isNotEmpty
                              ? 'No orders matched "$searchQuery" under ${filter.label}.'
                              : 'No orders currently in ${filter.label}.',
                          icon: Icons.receipt_long_outlined,
                          actionLabel: filter != OrderFilterTab.all ||
                                  searchQuery.isNotEmpty
                              ? 'Reset Filters'
                              : 'Refresh Board',
                          onAction: () {
                            if (filter != OrderFilterTab.all ||
                                searchQuery.isNotEmpty) {
                              _searchController.clear();
                              context
                                  .read<OrderSearchBloc>()
                                  .add(const OrderSearchCleared());
                              context.read<OrderFilterCubit>().reset();
                            } else {
                              context
                                  .read<OrderBoardBloc>()
                                  .add(const OrderBoardLoadRequested());
                            }
                          },
                        ),
                      OrderBoardLoaded(
                        :final orders,
                        :final hasMore,
                        :final isLoadingMore,
                      ) =>
                        RefreshIndicator(
                          onRefresh: () async {
                            final bloc = context.read<OrderBoardBloc>();
                            bloc.add(const OrderBoardRefreshRequested());
                            await bloc.stream.firstWhere(
                              (next) =>
                                  next is! OrderBoardLoaded || !next.isRefreshing,
                            );
                          },
                          child: ListView.separated(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: orders.length + (hasMore ? 1 : 0),
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index >= orders.length) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: isLoadingMore
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : OutlinedButton(
                                            onPressed: () => context
                                                .read<OrderBoardBloc>()
                                                .add(
                                                  const OrderBoardLoadMoreRequested(),
                                                ),
                                            child: const Text('Load More Orders'),
                                          ),
                                  ),
                                );
                              }
                              final order = orders[index];
                              return OrderCard(
                                order: order,
                                now: widget.clock.now(),
                                onTap: widget.onOrderTap == null
                                    ? null
                                    : () => widget.onOrderTap!(order),
                              );
                            },
                          ),
                        ),
                    };
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftSummaryStrip extends StatelessWidget {
  const _ShiftSummaryStrip({required this.stats});

  final MerchantShiftStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _KpiChip(
              label: 'Active Queue',
              value: '${stats!.activeCount}',
              color: colorScheme.primaryContainer,
              onColor: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            _KpiChip(
              label: 'Completed',
              value: '${stats!.completedToday}',
              color: colorScheme.secondaryContainer,
              onColor: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            _KpiChip(
              label: 'Shift Revenue',
              value: formatVnd(stats!.revenueTodayVnd),
              color: colorScheme.surfaceContainerHighest,
              onColor: colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({
    required this.label,
    required this.value,
    required this.color,
    required this.onColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(color: onColor),
          ),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterTabs extends StatelessWidget {
  const _StatusFilterTabs({
    required this.selected,
    required this.onSelected,
  });

  final OrderFilterTab selected;
  final ValueChanged<OrderFilterTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: OrderFilterTab.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = OrderFilterTab.values[index];
          return ChoiceChip(
            label: Text(tab.label),
            selected: tab == selected,
            onSelected: (_) => onSelected(tab),
          );
        },
      ),
    );
  }
}
