import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';
import 'package:orderpulse_flutter/core/router/app_router.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/theme/theme_cubit.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/core/widgets/state_views.dart';
import 'package:orderpulse_flutter/core/widgets/status_badge.dart';
import 'package:orderpulse_flutter/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:orderpulse_flutter/features/insights/presentation/bloc/shift_insights_cubit.dart';
import 'package:orderpulse_flutter/features/insights/presentation/widgets/shift_insights_view.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_sla.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_board_bloc.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_filter_cubit.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_search_bloc.dart';
import 'package:orderpulse_flutter/features/orders/presentation/widgets/order_card.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_event.dart';
import 'package:orderpulse_flutter/features/realtime/presentation/bloc/order_stream_bloc.dart';
import 'package:orderpulse_flutter/features/realtime/presentation/widgets/connection_status_bar.dart';
import 'package:orderpulse_flutter/features/simulator/presentation/bloc/simulator_cubit.dart';
import 'package:orderpulse_flutter/features/simulator/presentation/widgets/simulator_sheet.dart';

/// Dependency-injected entry point for the merchant order dispatch board & insights shell.
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
    final streamBloc = sl<OrderStreamBloc>();
    if (streamBloc.state is OrderStreamOffline) {
      streamBloc.add(const OrderStreamConnectRequested());
    }
    final insightsCubit = sl<ShiftInsightsCubit>();
    if (insightsCubit.state.orders.isEmpty && !insightsCubit.state.isLoading) {
      unawaited(insightsCubit.loadShiftOrders());
    }
  }

  @override
  Widget build(BuildContext context) {
    final simulatorCubit = sl<SimulatorCubit>();
    final streamBloc = sl<OrderStreamBloc>();
    final insightsCubit = sl<ShiftInsightsCubit>();

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<OrderBoardBloc>()),
        BlocProvider.value(value: sl<OrderFilterCubit>()),
        BlocProvider.value(value: sl<OrderSearchBloc>()),
        BlocProvider.value(value: streamBloc),
        BlocProvider.value(value: simulatorCubit),
        BlocProvider.value(value: insightsCubit),
      ],
      child: BlocBuilder<ShiftInsightsCubit, ShiftInsightsState>(
        builder: (context, insightsState) {
          return OrderBoardView(
            clock: sl<AppClock>(),
            shiftOrders: insightsState.orders,
            onRefreshShiftOrders: () => insightsCubit.loadShiftOrders(),
            onOrderUpsertSync: insightsCubit.upsertOrder,
            onOrderTap: (order) => context.push(
              AppRoutes.orderDetail(order.id),
              extra: order,
            ),
            extraActions: [
              if (simulatorCubit.state.isSupported)
                IconButton(
                  tooltip: 'Open Simulator',
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 48),
                  padding: EdgeInsets.zero,
                  onPressed: () => SimulatorSheet.show(
                    context,
                    simulatorCubit: simulatorCubit,
                    orderStreamBloc: streamBloc,
                  ),
                  icon: const Icon(Icons.science_outlined),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Declarative 2-tab KDS board rendering Live Queue and Shift Insights.
class OrderBoardView extends StatefulWidget {
  const OrderBoardView({
    super.key,
    required this.clock,
    this.onOrderTap,
    this.extraActions = const [],
    this.shiftOrders,
    this.onRefreshShiftOrders,
    this.onOrderUpsertSync,
    this.initialTabIndex = 0,
    this.slaTickInterval = const Duration(seconds: 30),
  });

  final AppClock clock;
  final void Function(Order order)? onOrderTap;
  final List<Widget> extraActions;
  final List<Order>? shiftOrders;
  final Future<void> Function()? onRefreshShiftOrders;
  final ValueChanged<Order>? onOrderUpsertSync;
  final int initialTabIndex;
  final Duration slaTickInterval;

  @override
  State<OrderBoardView> createState() => _OrderBoardViewState();
}

class _OrderBoardViewState extends State<OrderBoardView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late int _selectedTabIndex;
  Timer? _slaTicker;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 1);
    _scrollController.addListener(_onScroll);
    if (widget.slaTickInterval > Duration.zero) {
      _slaTicker = Timer.periodic(widget.slaTickInterval, (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _slaTicker?.cancel();
    _slaTicker = null;
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

  void _handleStreamEvent(
    BuildContext context,
    OrderStreamState streamState,
  ) {
    if (streamState is! OrderStreamLive || streamState.latestEvent == null) {
      return;
    }
    final boardBloc = context.read<OrderBoardBloc>();
    switch (streamState.latestEvent!) {
      case OrderCreatedEvent(:final order):
        boardBloc.add(OrderBoardOrderUpserted(order, isNewIncoming: true));
        widget.onOrderUpsertSync?.call(order);
      case OrderCancelledEvent(:final orderId, :final reason):
        boardBloc.add(
          OrderBoardOrderCancelled(orderId: orderId, reason: reason),
        );
        unawaited(widget.onRefreshShiftOrders?.call());
      case RiderAssignedEvent(
          :final orderId,
          :final riderName,
          :final riderPlate,
        ):
        boardBloc.add(
          OrderBoardRiderAssigned(
            orderId: orderId,
            riderName: riderName,
            riderPlate: riderPlate,
          ),
        );
        unawaited(widget.onRefreshShiftOrders?.call());
    }
  }

  (String, String) _resolveAppBarTitles(AuthState authState) {
    if (authState case AuthAuthenticated(:final merchant)) {
      final branch = merchant.branchName.trim();
      final name = merchant.merchantName.trim();
      final subtitle = branch.isNotEmpty
          ? (branch.contains('•') || name.startsWith('OrderPulse')
              ? branch
              : '$branch • $name')
          : name;
      return ('OrderPulse', subtitle);
    }
    return ('OrderPulse', 'Kitchen Dispatch');
  }

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final (appBarTitle, appBarSubtitle) = _resolveAppBarTitles(authState);

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
        BlocListener<OrderStreamBloc, OrderStreamState>(
          listenWhen: (prev, curr) =>
              curr is OrderStreamLive &&
              curr.latestEvent != null &&
              prev != curr,
          listener: _handleStreamEvent,
        ),
      ],
      child: BlocBuilder<OrderBoardBloc, OrderBoardState>(
        builder: (context, boardState) {
          final now = widget.clock.now();
          final loadedOrders = boardState is OrderBoardLoaded
              ? boardState.orders
              : const <Order>[];
          final analyticsOrders =
              (widget.shiftOrders != null && widget.shiftOrders!.isNotEmpty)
                  ? widget.shiftOrders!
                  : loadedOrders;

          final activeSource = analyticsOrders.isNotEmpty
              ? analyticsOrders.where((o) => o.status.isActive).toList()
              : loadedOrders.where((o) => o.status.isActive).toList();
          final activeCount =
              boardState.stats?.activeCount ?? activeSource.length;
          final urgentSlaCount = activeSource
              .where((o) => OrderSlaEvaluator.evaluate(o, now).urgency.isUrgent)
              .length;
          final readyCount = activeSource
              .where((o) => o.status == OrderStatus.ready)
              .length;

          return Scaffold(
            appBar: AppBar(
              titleSpacing: 16,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appBarTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: kds.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    appBarSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: kds.textSecondary,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
              actions: [
                BlocBuilder<OrderStreamBloc, OrderStreamState>(
                  builder: (context, streamState) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _AppBarLivePill(state: streamState),
                    );
                  },
                ),
                ...widget.extraActions,
                IconButton(
                  tooltip: 'Toggle theme',
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 48),
                  padding: EdgeInsets.zero,
                  onPressed: () => context.read<ThemeCubit>().toggle(),
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 48),
                  padding: const EdgeInsets.only(right: 4),
                  onPressed: () =>
                      context.read<AuthBloc>().add(const AuthLogoutRequested()),
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
            body: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _LiveQueueTab(
                    clock: widget.clock,
                    now: now,
                    boardState: boardState,
                    activeCount: activeCount,
                    urgentSlaCount: urgentSlaCount,
                    readyCount: readyCount,
                    searchController: _searchController,
                    scrollController: _scrollController,
                    onOrderTap: widget.onOrderTap,
                    onRefresh: () async {
                      final bloc = context.read<OrderBoardBloc>();
                      bloc.add(const OrderBoardRefreshRequested());
                      await Future.wait([
                        bloc.stream.firstWhere(
                          (next) =>
                              next is! OrderBoardLoaded || !next.isRefreshing,
                        ),
                        if (widget.onRefreshShiftOrders != null)
                          widget.onRefreshShiftOrders!(),
                      ]);
                    },
                  ),
                  ShiftInsightsView(
                    orders: analyticsOrders,
                    now: now,
                    onRefresh: widget.onRefreshShiftOrders ??
                        () async {
                          final bloc = context.read<OrderBoardBloc>();
                          bloc.add(const OrderBoardRefreshRequested());
                          await bloc.stream.firstWhere(
                            (next) =>
                                next is! OrderBoardLoaded || !next.isRefreshing,
                          );
                        },
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: kds.border)),
              ),
              child: NavigationBar(
                height: 68,
                selectedIndex: _selectedTabIndex,
                onDestinationSelected: (index) {
                  if (_selectedTabIndex == index) return;
                  setState(() => _selectedTabIndex = index);
                  if (index == 1) {
                    unawaited(widget.onRefreshShiftOrders?.call());
                  }
                },
                destinations: [
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: activeCount > 0,
                      label: Text('$activeCount'),
                      child: const Icon(Icons.receipt_long_outlined),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: activeCount > 0,
                      label: Text('$activeCount'),
                      child: const Icon(Icons.receipt_long_rounded),
                    ),
                    label: 'Live Queue',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights_rounded),
                    label: 'Shift Insights',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppBarLivePill extends StatelessWidget {
  const _AppBarLivePill({required this.state});

  final OrderStreamState state;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final (bg, fg, border, dot, text) = switch (state) {
      OrderStreamLive() => (
          kds.statusReadyContainer,
          kds.onStatusReadyContainer,
          kds.statusReady,
          kds.statusReady,
          'LIVE',
        ),
      OrderStreamConnecting() || OrderStreamReconnecting() => (
          kds.statusNewContainer,
          kds.onStatusNewContainer,
          kds.statusNew,
          kds.statusNew,
          'SYNCING',
        ),
      OrderStreamOffline() => (
          kds.statusRejectedContainer,
          kds.onStatusRejectedContainer,
          kds.statusRejected,
          kds.statusRejected,
          'OFFLINE',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: tabularStyle(
              textTheme.labelSmall?.copyWith(
                color: fg,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveQueueTab extends StatelessWidget {
  const _LiveQueueTab({
    required this.clock,
    required this.now,
    required this.boardState,
    required this.activeCount,
    required this.urgentSlaCount,
    required this.readyCount,
    required this.searchController,
    required this.scrollController,
    required this.onRefresh,
    this.onOrderTap,
  });

  final AppClock clock;
  final DateTime now;
  final OrderBoardState boardState;
  final int activeCount;
  final int urgentSlaCount;
  final int readyCount;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(Order order)? onOrderTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlocBuilder<OrderStreamBloc, OrderStreamState>(
          builder: (context, streamState) {
            return ConnectionStatusBar(
              state: streamState,
              onReconnectTap: () => context
                  .read<OrderStreamBloc>()
                  .add(const OrderStreamConnectRequested()),
            );
          },
        ),
        if (boardState case OrderBoardLoaded(:final incomingAlertOrder?))
          _IncomingOrderBanner(
            order: incomingAlertOrder,
            onView: onOrderTap == null
                ? null
                : () {
                    context
                        .read<OrderBoardBloc>()
                        .add(const OrderBoardAlertDismissed());
                    onOrderTap!(incomingAlertOrder);
                  },
            onDismiss: () => context
                .read<OrderBoardBloc>()
                .add(const OrderBoardAlertDismissed()),
          ),
        _QueueSummaryStrip(
          activeCount: activeCount,
          urgentSlaCount: urgentSlaCount,
          readyCount: readyCount,
          isUrgentFilterActive: boardState.urgentOnly,
          onUrgentTap: () => context
              .read<OrderBoardBloc>()
              .add(const OrderBoardUrgentFilterToggled()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: searchController,
            onChanged: (value) => context
                .read<OrderSearchBloc>()
                .add(OrderSearchQueryChanged(value)),
            decoration: InputDecoration(
              hintText: 'Search order ID or customer...',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: searchController,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      searchController.clear();
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
          onSelected: (tab) => context.read<OrderFilterCubit>().selectTab(tab),
        ),
        const SizedBox(height: 6),
        _SlaTriageAndSortBar(
          urgentOnly: boardState.urgentOnly,
          sortMode: boardState.sortMode,
          urgentSlaCount: urgentSlaCount,
          onToggleUrgent: () => context
              .read<OrderBoardBloc>()
              .add(const OrderBoardUrgentFilterToggled()),
          onToggleSort: () => context.read<OrderBoardBloc>().add(
                OrderBoardSortModeChanged(
                  boardState.sortMode == OrderSortMode.slaUrgencyFirst
                      ? OrderSortMode.newestFirst
                      : OrderSortMode.slaUrgencyFirst,
                ),
              ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: switch (boardState) {
            OrderBoardLoading() => const LoadingStateView(
                message: 'Loading live merchant orders...',
              ),
            OrderBoardError(:final message) => ErrorStateView(
                message: message,
                onRetry: () => context
                    .read<OrderBoardBloc>()
                    .add(const OrderBoardLoadRequested()),
              ),
            OrderBoardEmpty(
              :final filter,
              :final searchQuery,
              :final urgentOnly,
            ) =>
              EmptyStateView(
                title: urgentOnly ? 'No urgent SLA orders' : 'No matching orders',
                subtitle: urgentOnly
                    ? 'All tickets under ${filter.label} are currently within safe SLA windows.'
                    : (searchQuery.isNotEmpty
                        ? 'No orders matched "$searchQuery" under ${filter.label}.'
                        : 'No orders currently in ${filter.label}.'),
                icon: Icons.receipt_long_outlined,
                actionLabel: filter != OrderFilterTab.all ||
                        searchQuery.isNotEmpty ||
                        urgentOnly
                    ? 'Reset Filters'
                    : 'Refresh Board',
                onAction: () {
                  if (filter != OrderFilterTab.all ||
                      searchQuery.isNotEmpty ||
                      urgentOnly) {
                    searchController.clear();
                    context
                        .read<OrderSearchBloc>()
                        .add(const OrderSearchCleared());
                    context.read<OrderFilterCubit>().reset();
                    context
                        .read<OrderBoardBloc>()
                        .add(const OrderBoardUrgentFilterChanged(false));
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
                onRefresh: onRefresh,
                child: ListView.separated(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: orders.length + (hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index >= orders.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                                      .add(const OrderBoardLoadMoreRequested()),
                                  child: const Text('Load More Orders'),
                                ),
                        ),
                      );
                    }
                    final order = orders[index];
                    return OrderCard(
                      order: order,
                      now: clock.now(),
                      onTap:
                          onOrderTap == null ? null : () => onOrderTap!(order),
                    );
                  },
                ),
              ),
          },
        ),
      ],
    );
  }
}

class _IncomingOrderBanner extends StatelessWidget {
  const _IncomingOrderBanner({
    required this.order,
    required this.onDismiss,
    this.onView,
  });

  final Order order;
  final VoidCallback? onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kds.statusNewContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kds.statusNew.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_rounded,
            color: kds.onStatusNewContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'New Order ${order.id}',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: kds.onStatusNewContainer,
                  ),
                ),
                Text(
                  '${order.customerName} • ${formatVnd(order.totalAmountVnd)}',
                  style: tabularStyle(
                    textTheme.bodySmall?.copyWith(
                      color: kds.onStatusNewContainer,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onView != null)
            TextButton(
              onPressed: onView,
              child: const Text('View'),
            ),
          IconButton(
            tooltip: 'Dismiss alert',
            onPressed: onDismiss,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: kds.onStatusNewContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueSummaryStrip extends StatelessWidget {
  const _QueueSummaryStrip({
    required this.activeCount,
    required this.urgentSlaCount,
    required this.readyCount,
    required this.isUrgentFilterActive,
    required this.onUrgentTap,
  });

  final int activeCount;
  final int urgentSlaCount;
  final int readyCount;
  final bool isUrgentFilterActive;
  final VoidCallback onUrgentTap;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: _QueueStatTile(
              label: 'Active',
              value: '$activeCount',
              icon: Icons.local_fire_department_outlined,
              bg: kds.statusPreparingContainer,
              fg: kds.onStatusPreparingContainer,
              border: kds.statusPreparing,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QueueStatTile(
              label: 'Urgent SLA',
              value: '$urgentSlaCount',
              icon: Icons.warning_amber_rounded,
              bg: urgentSlaCount > 0 || isUrgentFilterActive
                  ? kds.statusRejectedContainer
                  : kds.cardElevated,
              fg: urgentSlaCount > 0 || isUrgentFilterActive
                  ? kds.onStatusRejectedContainer
                  : kds.textSecondary,
              border: urgentSlaCount > 0 || isUrgentFilterActive
                  ? kds.statusRejected
                  : kds.border,
              isHighlighted: isUrgentFilterActive,
              onTap: onUrgentTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QueueStatTile(
              label: 'Ready',
              value: '$readyCount',
              icon: Icons.inventory_2_outlined,
              bg: kds.statusReadyContainer,
              fg: kds.onStatusReadyContainer,
              border: kds.statusReady,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueStatTile extends StatelessWidget {
  const _QueueStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.border,
    this.isHighlighted = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color border;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: border.withValues(alpha: isHighlighted ? 1.0 : 0.55),
              width: isHighlighted ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: fg),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: tabularStyle(
                  textTheme.titleMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
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

class _SlaTriageAndSortBar extends StatelessWidget {
  const _SlaTriageAndSortBar({
    required this.urgentOnly,
    required this.sortMode,
    required this.urgentSlaCount,
    required this.onToggleUrgent,
    required this.onToggleSort,
  });

  final bool urgentOnly;
  final OrderSortMode sortMode;
  final int urgentSlaCount;
  final VoidCallback onToggleUrgent;
  final VoidCallback onToggleSort;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final isUrgencySort = sortMode == OrderSortMode.slaUrgencyFirst;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          FilterChip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: urgentOnly
                  ? kds.onStatusRejectedContainer
                  : (urgentSlaCount > 0 ? kds.statusRejected : kds.textSecondary),
            ),
            label: const Text('Urgent SLA'),
            selected: urgentOnly,
            showCheckmark: false,
            selectedColor: kds.statusRejectedContainer,
            side: BorderSide(
              color: urgentOnly
                  ? kds.statusRejected
                  : (urgentSlaCount > 0
                      ? kds.statusRejected.withValues(alpha: 0.45)
                      : kds.border),
            ),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: urgentOnly
                  ? kds.onStatusRejectedContainer
                  : kds.textPrimary,
            ),
            onSelected: (_) => onToggleUrgent(),
          ),
          const SizedBox(width: 8),
          FilterChip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: isUrgencySort ? kds.brandAccent : kds.textSecondary,
            ),
            label: const Text('SLA Urgency First'),
            selected: isUrgencySort,
            showCheckmark: false,
            selectedColor: kds.brandAccent.withValues(alpha: 0.16),
            side: BorderSide(
              color: isUrgencySort ? kds.brandAccent : kds.border,
            ),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isUrgencySort ? kds.brandAccent : kds.textPrimary,
            ),
            onSelected: (_) => onToggleSort(),
          ),
        ],
      ),
    );
  }
}
